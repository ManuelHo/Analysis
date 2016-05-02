module namespace analysis = 'http://www.dke.jku.at/MBA/Analysis';

declare namespace xes = 'http://www.xes-standard.org/';

import module namespace mba = 'http://www.dke.jku.at/MBA' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/mba.xqm';
import module namespace sc = 'http://www.w3.org/2005/07/scxml' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/scxml.xqm';
import module namespace functx = 'http://www.functx.com' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/functx.xqm';

(: returns total average cycle time of MBA at a certain level :)
declare function analysis:getTotalActualCycleTime($mba as element(),
        $level as xs:string,
        $toState as xs:string?
) as xs:duration {
    let $descendants := (: if the topLevel is $level, analyze $mba :)
        analysis:getDescendantsAtLevelOrMBA($mba, $level, $toState)

    let $cycleTimes :=
        for $descendant in $descendants
        return analysis:getCycleTimeOfInstance($descendant, $toState)

    return fn:avg($cycleTimes)
};

(: returns cycle time of top level from MBA :)
(: as time between start and end :)
declare function analysis:getCycleTimeOfInstance($mba as element(),
        $toState as xs:string?
) as xs:duration {
    let $stateLog := analysis:getStateLogToState($mba, $toState)/state

    let $cycleTimeOfInstance :=
        (if ($stateLog[last()]/@until) then
            xs:dateTime($stateLog[last()]/@until)
        else
            fn:current-dateTime()
        ) - xs:dateTime(($stateLog/@from)[1])

    return $cycleTimeOfInstance
};

declare function analysis:getTotalCycleTime($mba as element(),
        $level as xs:string,
        $inState as xs:string?,
        $excludeArchiveStates as xs:boolean?,
        $changedStates as element()*,
        $changedTransitions as element()*,
        $changedTransitionsFactors as xs:decimal*
) as xs:duration {
    let $scxml := analysis:getSCXMLAtLevel($mba, $level)

    let $states := analysis:getMostAbstractStates($scxml, $excludeArchiveStates)

    return (: Archive states can only be on the 'first' level. :)
        sum(
                for $state in $states (: 'first level' states except for sc:initial :)
                return
                    analysis:getCycleTimeForCompositeState($mba, $level, $inState, $state, $changedStates, $changedTransitions, $changedTransitionsFactors, ())
        )
};

declare function analysis:getTotalCycleTimeToState($mba as element(),
        $level as xs:string,
        $inState as xs:string?,
        $toState as xs:string,
        $changedStates as element()*,
        $changedTransitions as element()*,
        $changedTransitionsFactors as xs:decimal*
) as xs:duration {
    let $scxml := analysis:getSCXMLAtLevel($mba, $level)

    let $state := $scxml//*[@id = $toState]

    let $transitions := analysis:getTransitionsToState($scxml, $state, true(), true())

    let $stateList := functx:distinct-deep(
            for $t in $transitions
            let $source := sc:getSourceState($t)
            return
                analysis:getStateList($mba, $level, $inState, $source, $changedStates, $changedTransitions, $changedTransitionsFactors, $toState)
    )

    return (: if list contains composite states, remove all states that have parent states in list :)
        fn:sum(
                for $state in $stateList
                let $parentStates := analysis:getParentStates($scxml, $state/@id)
                return
                    if (not($parentStates = $stateList/@id)) then (: if no parent is in $stateList, add $state :)
                        xs:dayTimeDuration($state/@averageCycleTime)
                    else
                        ()
        )
};

(: flow analysis with $toState :)
(: starting with $toState, returns a list of states of all the paths until <sc:initial> :)
(: may contain duplicates :)
declare function analysis:getStateList($mba as element(),
        $level as xs:string,
        $inState as xs:string?,
        $state as element(),
        $changedStates as element()*,
        $changedTransitions as element()*,
        $changedTransitionsFactors as xs:decimal*,
        $toState as xs:string
) as element()* {
    let $scxml := analysis:getSCXMLAtLevel($mba, $level)

    (: this method assures that all transitions are considered, which lead to the given state :)
    (: ToDo: problem with rework loops, not working at the moment :)
    let $transitions := analysis:getTransitionsToState($scxml, $state, true(), true())

    let $stateList :=
        for $t in $transitions
        let $source := sc:getSourceState($t)
        let $cycleTime := analysis:getCycleTimeForCompositeState($mba, $level, $inState, $state, $changedStates, $changedTransitions, $changedTransitionsFactors, $toState)
        return
            (
                if (not(empty($cycleTime))) then
                    element {'state'} {
                        $state/@id,
                        attribute averageCycleTime {$cycleTime}
                    }
                else ()
                ,
                analysis:getStateList($mba, $level, $inState, $source, $changedStates, $changedTransitions, $changedTransitionsFactors, $toState)(: next state, ToDo: only if @reworkStart=false :)
            )

    return $stateList
};

declare function analysis:getProblematicStates($mba as element(),
        $level as xs:string,
        $inState as xs:string?,
        $excludeArchiveStates as xs:boolean?,
        $threshold as xs:decimal?
) as element()* {
(: return all states whith average cycle time of more than $threshold times total cycle time :)
(: DECISION: cycleTime will be calculated for whole process, with the option to exclude archiveStates and only include descendants which are $inState :)
    let $totalCycleTime := analysis:getTotalCycleTime($mba, $level, $inState, $excludeArchiveStates, (), (), ())
    let $cycleTimeThreshold := $totalCycleTime * $threshold

    let $scxml := analysis:getSCXMLAtLevel($mba, $level)
    let $states := analysis:getStates($scxml, $excludeArchiveStates)

    return
        for $state in $states
        let $cycleTime := analysis:getCycleTimeForCompositeState($mba, $level, $inState, $state, (), (), (), ())
        return
            if ($cycleTime >= $cycleTimeThreshold) then
                $state
            else
                ()
};

(: this function check the topLevel of $mba :)
declare function analysis:getCausesOfProblematicStates(
        $mba as element(),
        $level as xs:string,
        $inState as xs:string?,
        $excludeArchiveStates as xs:boolean?,
        $threshold as xs:decimal?
) {
(:
        return the cause of all problematic states, e.g. like
        A because of B

        e.g. check if a problematic state has high cycle time because of previous state

        If there is a substate which is also problematic AND ends at the same time as the state, the substate is the bottleneck.
        If there is a multilevel synchronization dependency:
            - check if there is a problematic state which causes the bottleneck.
    :)
    let $threshold :=
        if (not($threshold)) then
            0.3
        else
            $threshold

    let $problematicStates := analysis:getProblematicStates($mba, $level, $inState, $excludeArchiveStates, $threshold)

    return
        for $state in $problematicStates
        return analysis:getCausesOfProblematicState($mba, $level, $state, $inState, $excludeArchiveStates, $threshold, $problematicStates, false())
};

(: checks what is causing $state to be problematic :)
(: $checkSynchronizedProcess: if true(), function was called from a path of a synchronized process. ProblematicStates in synchronized processes are causing delays the parallel process :)
(:
    $inState is only used for $level of first call (from user - $inState is null if function is called for another level)
    $changedStates/$changedTransitions are not used. Otherwise the $stateLog has to be constructed.
    $toState not used, instead there is the option to $excludeArchiveStates.
:)
declare function analysis:getCausesOfProblematicState($mba as element(),
        $level as xs:string,
        $state as element(),
        $inState as xs:string?,
        $excludeArchiveStates as xs:boolean?,
        $threshold as xs:decimal?,
        $problematicStates as element()*,
        $checkSynchronizedProcess as xs:boolean
) {
    if (analysis:stateIsInitialOfSCXML($state) = true()) then (: initial state of scxml, end recursion :)
        fn:concat("  --> Process on level: '", $level, "'")
    else if (analysis:stateIsInitial($state) = true()) then
    (: call again for parent :)
        analysis:getCausesOfProblematicState($mba, $level, $state/.., $inState, $excludeArchiveStates, $threshold, $problematicStates, $checkSynchronizedProcess)
    else
        (
            if ($state/@id = $problematicStates/@id) then
                fn:concat( (: if state is problematic, print state + time:)
                        fn:string($state/@id),
                        '[', analysis:getCycleTimeForCompositeState($mba, $level, $inState, $state, (), (), (), ()), ']'
                )
            else ()
            ,
            analysis:getProblematicSubstates($mba, $level, $state, $inState, $problematicStates)
            ,
            for $t in $state//sc:transition
            return
                if ($t/@cond) then
                    let $syncFunction := analysis:parseFunction($t/@cond)
                    let $syncLevel := analysis:parseLevelName($t/@cond)
                    let $syncStateId := analysis:parseStateId($t/@cond)
                    return
                        if (
                            ($syncFunction = "$_everyDescendantAtLevelIsInState") or
                                    ($syncFunction = "$_someDescendantAtLevelIsInState")) then (: "$_everyDescendantAtLevelIsInState('levelName', 'StateId')" :)
                            analysis:getCausesOfProblematicStateMBAAtLevelIsInState($mba, $level, $state, $excludeArchiveStates, $threshold, $syncFunction, $syncLevel, $syncStateId)
                        else if ($syncFunction = "$_ancestorAtLevelIsInState") then
                            analysis:getCausesOfProblematicStateAncestorAtLevelIsInState($mba, $level, $state, $excludeArchiveStates, $threshold, $syncFunction, $syncLevel, $syncStateId)
                        else
                            ()(: ToDo: implement other sync. functions. Else: () :)
                else
                    () (: no cond --> no check needed for sync :)
            ,
            if ($checkSynchronizedProcess = true()) then
            (: follow process until initial/problematicState :)
                analysis:getCauseOfProblematicSync($mba, $level, $state, $excludeArchiveStates, $threshold)
            else
                ()
        )
};

(: to prevent errors, this function checks if the $mba contains a scxml-element for $syncLevel. If not, it replaces $mba with the ancestor at $syncLevel. :)
declare function analysis:getCausesOfProblematicStateAncestorAtLevelIsInState($mba as element(),
        $level as xs:string,
        $state as element(),
        $excludeArchiveStates as xs:boolean?,
        $threshold as xs:decimal?,
        $syncFunction as xs:string,
        $syncLevel as xs:string,
        $syncStateId as xs:string
) (:as xs:string*:) {
(: ancestor: check if level is in $mba. If not, check ancestors :)
    let $scxml := analysis:getSCXMLAtLevel($mba, $syncLevel)
    return
        if ($scxml) then
            analysis:getCausesOfProblematicStateMBAAtLevelIsInState($mba, $level, $state, $excludeArchiveStates, $threshold, $syncFunction, $syncLevel, $syncStateId)
        else
            analysis:getCausesOfProblematicStateMBAAtLevelIsInState(mba:getAncestorAtLevel($mba, $syncLevel), $level, $state, $excludeArchiveStates, $threshold, $syncFunction, $syncLevel, $syncStateId)
};

(: moved logic for function $_everyDescendantAtLevelIsInState :)
declare function analysis:getCausesOfProblematicStateMBAAtLevelIsInState($mba as element(),
        $level as xs:string,
        $state as element(),
        $excludeArchiveStates as xs:boolean?,
        $threshold as xs:decimal?,
        $syncFunction as xs:string,
        $syncLevel as xs:string,
        $syncStateId as xs:string
) (:as xs:string*:) {
    let $syncSCXML := analysis:getSCXMLAtLevel($mba, $syncLevel)
    let $syncState := $syncSCXML//(sc:state | sc:parallel | sc:final)[@id = $syncStateId]

    let $syncCausingProblem := analysis:isSyncCausingProblem($mba, $level, $state, $syncFunction, $syncLevel, $syncStateId)

    (: check if @until of problematic state is shortly after( within 5 minutes) @from of preceding state at least ONCE :)
    return
        if ($syncCausingProblem = true()) then
            analysis:getCauseOfProblematicSync($mba, $syncLevel, $syncState, $excludeArchiveStates, $threshold)
        else
            ()(: time is totally different, $state is not delayed by sync :)
};

declare function analysis:isSyncCausingProblem($mba as element(),
        $level as xs:string,
        $state as element(),
        $syncFunction as xs:string,
        $syncLevel as xs:string,
        $syncStateId as xs:string
) {
    let $descendants := analysis:getDescendantsAtLevelOrMBA($mba, $level, ())
    return (: for each descendant check if there is a problem with this sync :)
        functx:is-value-in-sequence(
                true()
                ,
                for $descendant in $descendants
                let $stateLog := analysis:getStateLog($descendant)
                let $untilProblemState := $stateLog/state[@ref = $state/@id]/@until
                let $fromTimeSyncState :=
                    if($syncFunction = "$_ancestorAtLevelIsInState") then
                        analysis:getFromTimeOfState(mba:getAncestorAtLevel($descendant, $syncLevel), $syncLevel, $syncStateId, $syncFunction)
                    else (: descendants :)
                        analysis:getFromTimeOfState($descendant, $syncLevel, $syncStateId, $syncFunction)
                return
                    if (fn:empty($untilProblemState) or fn:empty($fromTimeSyncState)) then
                        false()
                    else
                        analysis:timesAreSame($untilProblemState, $fromTimeSyncState)
        )
};

(: follow process and until there is a problematic state :)
declare function analysis:getCauseOfProblematicSync($mba as element(),
        $level as xs:string,
        $state as element(), (: syncState :)
        $excludeArchiveStates as xs:boolean?,
        $threshold as xs:decimal?
) (:as xs:string*:) {
    let $scxml := analysis:getSCXMLAtLevel($mba, $level)
    let $syncProblematicStates := analysis:getProblematicStates($mba, $level, (), $excludeArchiveStates, $threshold)
    (: "$_everyDescendantAtLevelIsInState"/"$_someDescendantAtLevelIsInState"/"$_ancestorAtLevelIsInState": $state depends on preceding states of syncState  :)
    let $precedingStates := analysis:getTransitionsToState($scxml, $state, true(), true())/..
    return
        if ($precedingStates/@id = $syncProblematicStates/@id) then (: at least one $precedingState is problematic :)
            for $prec in $precedingStates[@id = $syncProblematicStates/@id] (: print all preceding problematic states :)
            return
                fn:concat('  --> ', $prec/@id, '[', analysis:getCycleTimeForCompositeState($mba, $level, (), $prec, (), (), (), ()), ']')
            (: ToDo: test cascading problems. checks for further sync. dependencies :)
        else
        (: follow process until a problematic state is found or initial :)
            for $prec in $precedingStates
            return analysis:getCausesOfProblematicState($mba, $level, $prec, (), $excludeArchiveStates, $threshold, $syncProblematicStates, true())
};

(: returns correct @from from stateLogs of mba/level depending on $syncFunction :)
declare function analysis:getFromTimeOfState($mba as element(),
        $level as xs:string,
        $state as xs:string,
        $syncFunction as xs:string
) as xs:dateTime? {
    let $fromTimes := analysis:getAllFromTimes($mba, $level, $state)
    return
        if ($syncFunction = "$_everyDescendantAtLevelIsInState") then
            max($fromTimes)
        else if ($syncFunction = "$_someDescendantAtLevelIsInState") then
            min($fromTimes)
        else if ($syncFunction = "$_ancestorAtLevelIsInState") then
                min($fromTimes) (: just to be safe. If there is a loop and $state is more than one time in $stateLog, take first occurence :)
            else
                ()
};

(: returns all @from times for a given state :)
declare function analysis:getAllFromTimes($mba as element(),
        $level as xs:string,
        $state as xs:string
) as xs:dateTime* {
    for $descendant in analysis:getDescendantsAtLevelOrMBA($mba, $level, ())
    let $subStateLog := analysis:getStateLog($descendant)
    return xs:dateTime($subStateLog/state[@ref = $state]/@from)
};

(: called from getCausesOfProblematicState, checks if a substate of $state is causing a delay and returns "  --> @id [<time>]" if yes :)
declare function analysis:getProblematicSubstates($mba as element(),
        $level as xs:string,
        $state as element(),
        $inState as xs:string?,
        $problematicStates as element()*
) as xs:string* {
    let $substates := $state//(sc:state | sc:parallel | sc:final)
    return
        if ($problematicStates/@id = $substates/@id) then (: check substates: if true at least one $substate is problematic :)
            for $sub in $substates[@id = $problematicStates/@id] (: print all problematic substates :)
            return fn:concat('  --> ', fn:string($sub/@id), '[', analysis:getCycleTimeForCompositeState($mba, $level, $inState, $sub, (), (), (), ()), ']')
            (: The reasons why these states are problematic are analyzed separately above :)
        else
            ()
};

declare function analysis:stateIsInitial($state as element()
) as xs:boolean {
    (fn:compare(fn:name($state), 'sc:initial') = 0)
};

declare function analysis:stateIsInitialOfSCXML($state as element()
) as xs:boolean {
    (fn:compare(fn:name($state), 'sc:initial') = 0) and
            (fn:compare(fn:name($state/..), 'sc:scxml') = 0)
};

(: true if two times are within 5 minutes :)
(: $time1 has to be AFTER $time2 :)
declare function analysis:timesAreSame($time1 as xs:dateTime,
        $time2 as xs:dateTime
) {
    if (($time2 <= $time1) and ($time1 - $time2 <= xs:dayTimeDuration("PT5M"))) then
        true()
    else
        false()
};

declare function analysis:getCycleTimeForCompositeState($mba as element(),
        $level as xs:string,
        $inState as xs:string?,
        $state as element(),
        $changedStates as element()*,
        $changedTransitions as element()*,
        $changedTransitionsFactors as xs:decimal*,
        $toState as xs:string?
) (:as xs:duration?:) {
    let $scxml := analysis:getSCXMLAtLevel($mba, $level)

    return
        if ($state/(descendant::sc:state | descendant::sc:parallel | descendant::sc:final)/@id = $changedStates/state/@id) then
        (: at least one descendant is changed :)
        (: IF parallel, return MAX branch, ELSE return sum of all substates :)
            let $cycleTimes :=
                for $substate in $state/(sc:state | sc:parallel | sc:final)
                return
                    analysis:getCycleTimeForCompositeState($mba, $level, $inState, $substate, $changedStates, $changedTransitions, $changedTransitionsFactors, $toState)
            return
                if (fn:compare(fn:name($state), 'sc:parallel') = 0) then
                    max($cycleTimes)
                else
                    fn:sum($cycleTimes)
        else
            analysis:getAverageCycleTime($mba, $level, $inState, $state/@id, $toState) *
                    analysis:getTransitionProbabilityForTargetState($scxml, $state, $changedTransitions, $changedTransitionsFactors, $toState, true(), true()) *
                    (
                        if ($state/@id = $changedStates/state/@id) then
                        (: $state is changed: changedFactor :)
                            number($changedStates/state[@id = $state/@id]/@factor)
                        else if ($state/(ancestor-or-self::sc:state | ancestor-or-self::sc:parallel | ancestor-or-self::sc:final)/@id = $changedStates/state/@id) then
                        (: parent is changed :)
                            number($changedStates/state[@id = $state/(ancestor-or-self::sc:state | ancestor-or-self::sc:parallel | ancestor-or-self::sc:final)/@id]/@factor)
                        else (: not changed :)
                            1
                    )
};

(: gets all transitions which result in entering $state :)
(: $includeSubstates: whether transitions with target=substateOf$state should be included or not. Needed for Calculation of @initial/<sc:initial> :)
declare function analysis:getTransitionsToState($scxml as element(),
        $state as element(),
        $includeSubstates as xs:boolean,
        $checkParallel as xs:boolean(: ## Workaround to avoid stackoverflow when initial is nested in child of parallel ## :)
) as element()* {
    if (analysis:stateIsInitialOfSCXML($state) = true()) then
    (: initial state of scxml :)
        ()
    else if (analysis:stateIsInitial($state) = true()) then
    (: <sc:initial>: transitions to parent ONLY, as there are no transitions to <sc:initial> :)
        analysis:getTransitionsToState($scxml, $state/.., false(), true())
    else if (
            (fn:compare(fn:name($state/..), 'sc:parallel') = 0) and
                    ($checkParallel = true())
        ) then
        (: <sc:parallel>: use transitions to parent :)
        (: trans. of parent: include transitions to itself as well as substates :)
        (: ### Workaround if initial is nested in child of parallel ### :)
        (: if $includeSubstates is false, then the function was called from initial/@initial --> do not include substates :)
        (: instead, get transitions for every sibling(incl. their substates) AND transitions of $state WITHOUT substates (because of initial) :)
        (: @initial is handled in else-branch :)
            (
                analysis:getTransitionsToState($scxml, $state/.., $includeSubstates, true())
                ,
                (
                    if ($includeSubstates = false()) then (: special treatment for substates of parallel :)
                        let $siblings := ($state/(following-sibling::sc:state | following-sibling::sc:parallel | following-sibling::sc:initial | following-sibling::sc:final)) |
                                ($state/(preceding-sibling::sc:state | preceding-sibling::sc:parallel | preceding-sibling::sc:initial | preceding-sibling::sc:final))
                        return
                            (
                                for $s in $siblings
                                return analysis:getTransitionsToState($scxml, $s, true(), false())(: $checkParallel is false :)
                                ,
                                analysis:getTransitionsToState($scxml, $state, $includeSubstates, false())(: $checkParallel is false :)
                            )
                    else
                        ()
                )
            )
        (: ### ### :)
        else
            let $substates := analysis:getStateAndSubstates($scxml, $state/@id)
            return
                (
                    if ($includeSubstates) then
                    (: include transitions where target is $state or a substate of $state, but only if source of transition is not also a substate of $state :)
                        $scxml//sc:transition[@target = $substates][not(functx:is-value-in-sequence(../@id, $substates))]
                    else
                    (: $includeSubstates = false, use transitions with target=$state only :)
                        $scxml//sc:transition[@target = $state/@id]
                    ,
                    (: if @initial, add transitions to parent state(WITHOUT substates!) :)
                    if (fn:compare(fn:string($state/../@initial), fn:string($state/@id)) = 0) then
                        analysis:getTransitionsToState($scxml, $state/.., false(), true())
                    else
                        ()
                )
};

(: calculate absolute probabilities of transitions, used as factors for total cycle time :)
(: $toState: include only descendants which have been/are in $toState :)
(: $includeSubstates: whether transitions with target=substateOf$state should be included or not. Needed for Calculation of @initial/<sc:initial> :)
declare function analysis:getTransitionProbabilityForTargetState($scxml as element(),
        $state as element(),
        $changedTransitions as element()*,
        $changedTransitionsFactors as xs:decimal*, (: ATTENTION: has to be in the same order as $changedTransitions! reason: node-identity :)
        $toState as xs:string?,
        $includeSubstates as xs:boolean,
        $checkParallel as xs:boolean(: ## Workaround to avoid stackoverflow when initial is nested in child of parallel ## :)
) as xs:decimal {
(:let $transitions := $scxml//sc:transition[@target=$state/@id]:)
    if (
        (fn:compare(fn:name($state), 'sc:initial') = 0) and
                (fn:compare(fn:name($state/..), 'sc:scxml') = 0)
    ) then
        1
    else
        let $transitions := analysis:getTransitionsToState($scxml, $state, $includeSubstates, $checkParallel)
        (:
            $transitions may contain duplicates. But this is excluded by assumption:
            when a transition is refined, the 'original' transition must not exist anymore!
        :)

        (: ToDo: problem with rework loops! Not possible at the moment

            If there is a rework loop, the probability for the affected states is greater 1.
            Formula: 1/(1-transProb)
        :)
        return fn:sum(
                for $transition in $transitions
                let $source := sc:getSourceState($transition)
                return
                    (
                        (
                            if (not(analysis:transitionInChangedTransitions($transition, $changedTransitions))) then
                                analysis:getTransitionProbability($transition, $toState)
                            else
                                $changedTransitionsFactors[position() = functx:index-of-node($changedTransitions, $transition)]
                        )
                                * analysis:getTransitionProbabilityForTargetState($scxml, $source, $changedTransitions, $changedTransitionsFactors, $toState, true(), true()))
                ,
                0
        )
};

(: returns true if a $transition is in a sequence of $changedTransitions, based on node identity :)
declare function analysis:transitionInChangedTransitions($transition as element(),
        $changedTransitions as element()*
) as xs:boolean {
    let $result :=
        for $t in $changedTransitions
        return
            if ($transition is $t) then
                true()
            else
                false()

    return functx:is-value-in-sequence(true(), $result)
};

(: relative probability :)
declare function analysis:getTransitionProbability($transition as element(),
        $toState as xs:string?
) as xs:decimal {
    let $mba := $transition/ancestor::mba:mba[last()]
    let $level := $transition/ancestor::mba:elements[1]/../@name
    let $descendants := (: if the topLevel is $level, analyze $mba :)
        analysis:getDescendantsAtLevelOrMBA($mba, $level, $toState)

    let $sourceState := sc:getSourceState($transition)

    (:
        for each descendant, check (via event log)
         - how often the source state of transition is left
         - how often the target state is entered via $transition
            - check for $source, $target, $event, $cond
    :)

    let $prob :=
        (: check if $transition/source is initial state :)
        (: assumption: if yes, probability is 1. As there is exactly one transition in an sc:initial element :)
        if (fn:compare(fn:name($sourceState), 'sc:initial') = 0) then
            <log leftState='true' tookTransition='true'/> (: probability: 1 :)
        else
            for $descendant in $descendants
            let $log := mba:getSCXML($descendant)/sc:datamodel/sc:data[@id = "_x"]/xes:log
            return
                for $event in $log/xes:trace/xes:event
                let $transitionEvent := analysis:getTransitionsForLogEntry(mba:getSCXML($descendant), $event)
                return (: left-state is true if state was left, took-transition is true if transition was taken :)
                    <log leftState='{analysis:stateIsLeft($transitionEvent, $sourceState/@id)}' tookTransition='{analysis:compareTransitions($transition, $transitionEvent)}'/>

    return
        if (fn:count($prob[@leftState = 'true']) > 0) then
            fn:count($prob[@tookTransition = 'true' and @leftState = 'true']) div fn:count($prob[@leftState = 'true'])
        else
            0
};

declare function analysis:stateIsLeft($transition as element(),
        $state as xs:string
) as xs:boolean {
(:
    true if:
        1. $transition/source = $state AND $transition/target is neither $state nor a substate
        2. $transition/source is a substate of $state AND $transition/target is neither $state nor a substate
    else false
:)
    if (fn:compare(fn:name(sc:getSourceState($transition)), 'sc:initial') = 0) then
        false()
    else
        let $sourceTransition := fn:string(sc:getSourceState($transition)/@id)
        let $targetTransition := fn:string($transition/@target)
        let $scxml := $transition/ancestor::sc:scxml[1]
        let $stateAndSubstates := analysis:getStateAndSubstates($scxml, $state)

        return
            if ($targetTransition and ($state = $sourceTransition) and (not(functx:is-value-in-sequence($targetTransition, $stateAndSubstates)))) then
                true() (: 1. :)
            else if ($targetTransition and (functx:is-value-in-sequence($sourceTransition, $stateAndSubstates)) and (not(functx:is-value-in-sequence($targetTransition, $stateAndSubstates)))) then
                true() (: 2. :)
            else
                false()
(: if $state is a substate of $transition/source --> no action, defined in documentation :)
};

declare function analysis:compareTransitions($origTransition as element(),
        $newTransition as element()
) as xs:boolean {
(:
    check if $origTransition is the 'same' as $newTransition
    rules:
        1. $newTransition may have a more specialized source state.
        2. $newTransition may have a more specialized target state.
            - If both have no target, then target check is ok
            - if source has no target, newTransition may have a target which is stateOrSubstate of source
        3. condition may be added to $newTransition (if $origTransition had no cond). If no condition, every cond can be introduced
        4. conditions in $newTransition may be specialized, by adding terms with 'AND'
        5. dot notation of events. If no event, every event can be introduced
:)

    let $origSource := fn:string(sc:getSourceState($origTransition)/@id)
    let $origTarget := fn:string($origTransition/@target)
    let $origEvent := fn:string($origTransition/@event)

    let $scxml := $newTransition/ancestor::sc:scxml[1]
    let $origSourceAndSubstates := analysis:getStateAndSubstates($scxml, $origSource)
    let $origTargetAndSubstates := analysis:getStateAndSubstates($scxml, $origTarget)

    return
        if (
        (: 1. :)(not(sc:getSourceState($origTransition)/@id or sc:getSourceState($newTransition)/@id) or functx:is-value-in-sequence(fn:string(sc:getSourceState($newTransition)/@id), $origSourceAndSubstates)) and
                (: 2. :)(not($origTransition/@target or $newTransition/@target)
                or functx:is-value-in-sequence(fn:string($newTransition/@target), $origTargetAndSubstates)
                or (not($origTransition/@target) and functx:is-value-in-sequence($newTransition/@target, $origSourceAndSubstates))) and
                (: 3&4:)(not($origTransition/@cond) or analysis:compareConditions($origTransition/@cond, $newTransition/@cond)) and
                (: 5. :)(not($origEvent) or analysis:compareEvents($origEvent, fn:string($newTransition/@event)))
        ) then
            true()
        else
            false()
};

(: returns average cycle time of a state :)
(: $toState: include only decendents which have been/are in $toState :)
declare function analysis:getAverageCycleTime($mba as element(),
        $level as xs:string,
        $inState as xs:string?,
        $stateId as xs:string,
        $toState as xs:string?
) as xs:duration? {
    let $descendants := (: if the topLevel is $level, analyze $mba :)
        (
            if ($mba/mba:topLevel[@name = $level]) then
                $mba
            else
                analysis:getDescendantsAtLevel($mba, $level, $toState)
        )[if ($inState) then mba:isInState(., $inState) else true()]

    let $cycleTimes :=
        for $descendant in $descendants
        let $stateLog := analysis:getStateLog($descendant)
        return
            fn:sum(
                    (
                        for $entry in $stateLog/state[@ref = $stateId] return
                            analysis:getCycleTimeOfStateLogEntry($entry)
                    ),
                    ()
            )

    return fn:avg($cycleTimes)
};

(: returns total cycle time an instance was in given states :)
(: $states must not be substates of each other! :)
declare function analysis:getTotalCycleTimeInStates($mba as element(),
        $level as xs:string,
        $states as xs:string*
) as xs:duration {
    let $stateLog := analysis:getStateLog($mba)

    return fn:sum(
            (
                for $entry in $stateLog/state[functx:is-value-in-sequence(@ref, $states)] return
                    analysis:getCycleTimeOfStateLogEntry($entry)
            ),
            ()
    )
};

(: returns state log for a mba :)
declare function analysis:getStateLog($mba as element()
) as element() {
    let $scxml := mba:getSCXML($mba)
    let $log := $scxml/sc:datamodel/sc:data[@id = "_x"]/xes:log

    (: get all events :)
    let $events := for $event in $log/xes:trace/xes:event
    order by $event/xes:date[@key = 'time:timestamp']/@value
    return $event

    let $stateLog := fn:fold-left($events,
            map:merge((
                map:entry('configuration', ()), (: stores state(s) that are currently entered :)
                map:entry('stateLog', ())
            )),
            function($result, $event) {
            (: get configuration and result entries from result-map :)
                let $configuration := map:get($result, 'configuration')
                let $stateLog := map:get($result, 'stateLog')

                let $eventTimestamp :=
                    xs:dateTime($event/xes:date[@key = 'time:timestamp']/@value)

                let $transition := analysis:getTransitionsForLogEntry($scxml, $event)

                let $entrySet := sc:computeEntrySet($transition) (: gets state(s) that are entered :)
                let $exitSet := sc:computeExitSet($configuration, $transition) (: nodes that are exited :)

                let $newStateLogEntries := for $state in $entrySet return
                    <state ref="{$state/@id}" from="{$eventTimestamp}"/>

                let $stateLog := for $entry in $stateLog return
                    if (not($entry/@until) and (some $state in $exitSet satisfies $state/@id = $entry/@ref)) then (: if there is an entry in the state log which has no until yet AND is in the exit set :)
                        copy $new := $entry modify (
                            insert node attribute until {$eventTimestamp} into $new
                        ) return $new
                    else $entry

                let $newConfiguration := ( (: update configuration, i.e. remove nodes which were left and therefore are in the exitSet :)
                $configuration[not(some $state in $exitSet satisfies $state is .)],
                $entrySet
                )

                return map:merge((
                    map:entry('configuration', $newConfiguration),
                    map:entry('stateLog', ($stateLog, $newStateLogEntries))
                ))
            }
    ) (: closing bracket fn:fold-left :)

    return <stateLog>{map:get($stateLog, 'stateLog')}</stateLog>
};

declare function analysis:getStateAndSubstates($scxml as element(),
        $state as xs:string
) as xs:string* {
    $scxml//(sc:state | sc:parallel | sc:final)[@id = $state]/(descendant-or-self::sc:state | descendant-or-self::sc:parallel | descendant-or-self::sc:final)/fn:string(@id)
};

declare function analysis:getParentStates($scxml as element(),
        $state as xs:string
) as xs:string* {
    $scxml//(sc:state | sc:parallel | sc:final)[@id = $state]/(ancestor::sc:state | ancestor::sc:parallel | ancestor::sc:final)/fn:string(@id)
};

declare function analysis:compareConditions($origCond as xs:string,
        $newCond as xs:string
) {
    (fn:compare($origCond, $newCond) = 0) or
            ((fn:compare($origCond, fn:substring($newCond, 1, fn:string-length($origCond))) = 0) and
                    (fn:compare(' and ', fn:substring($newCond, fn:string-length($origCond) + 1, 5)) = 0))
};

declare function analysis:compareEvents($origEvent as xs:string,
        $newEvent as xs:string
) as xs:boolean {
    (fn:compare($origEvent, $newEvent) = 0) or
            ((fn:compare($origEvent, fn:substring($newEvent, 1, fn:string-length($origEvent))) = 0) and
                    (fn:compare('.', fn:substring($newEvent, fn:string-length($origEvent) + 1, 1)) = 0))
};

(: Helper :)

declare function analysis:getTransitionsForLogEntry($scxml as element(),
        $event as element()
) as element() {
(: get properties of current event :)
    let $eventState := fn:string($event/xes:string[@key = 'sc:state']/@value)
    let $eventInitial := fn:string($event/xes:string[@key = 'sc:initial']/@value)
    let $eventEvent := fn:string($event/xes:string[@key = 'sc:event']/@value)
    let $eventTarget := fn:string($event/xes:string[@key = 'sc:target']/@value)
    let $eventCond := fn:string($event/xes:string[@key = 'sc:cond']/@value)

    (: get all transitions from scxml which comply to the current event :)
    let $transition :=
        $scxml//sc:transition[
        (not($eventEvent or @event) or @event = $eventEvent) and
                (not($eventTarget or @target) or @target = $eventTarget) and
                (not($eventCond or @cond) or @cond = $eventCond) and
                (not($eventState) or ../@id = $eventState) and
                (not($eventInitial) or (../../@id = $eventInitial or ../../@name = $eventInitial))
        ]
    return $transition
};

declare function analysis:getCycleTimeOfStateLogEntry($stateLogEntry as element()
) as xs:duration {
    if ($stateLogEntry/@until) then
        xs:dateTime($stateLogEntry/@until) -
                xs:dateTime($stateLogEntry/@from)
    else fn:current-dateTime() -
            xs:dateTime($stateLogEntry/@from)
};

declare function analysis:getStateLogToState($mba as element(),
        $toState as xs:string?
) as element(){
    let $stateLog := analysis:getStateLog($mba)
    return
        if ($toState) then
            element {fn:node-name($stateLog)} {$stateLog/state[@ref = $toState]/preceding-sibling::state}
        else
            $stateLog
};

declare function analysis:getSCXMLAtLevel($mba as element(),
        $level as xs:string
) as element()* {
        ($mba/mba:topLevel[@name = $level])/mba:elements/sc:scxml |
                ($mba//mba:childLevel[@name = $level])[1]/mba:elements/sc:scxml
};

(: returns descendants which have been in $toState :)
declare function analysis:getDescendantsAtLevel($mba as element(),
        $level as xs:string,
        $toState as xs:string?
) as element()* {
    let $descendants := mba:getDescendantsAtLevel($mba, $level)
    return
        if ($toState) then
            for $d in $descendants
            return
                if (analysis:getStateLog($d)/state[@ref = $toState]) then
                    $d
                else
                    ()
        else
            $descendants
};

(: returns all states of $scxml, depending on $excludeArchiveStates :)
declare function analysis:getStates($scxml as element(),
        $excludeArchiveStates as xs:boolean?
) as element()* {
    if ($excludeArchiveStates = true()) then
        $scxml//(sc:state | sc:parallel | sc:final)[not(@mba:isArchiveState = $excludeArchiveStates)]
    else
        $scxml//(sc:state | sc:parallel | sc:final)
};

(: returns only the most abstract states(=no substates) of $scxml, depending on $excludeArchiveStates :)
declare function analysis:getMostAbstractStates($scxml as element(),
        $excludeArchiveStates as xs:boolean?
) as element()* {
    if ($excludeArchiveStates = true()) then
        $scxml/(sc:state | sc:parallel | sc:final)[not(@mba:isArchiveState = $excludeArchiveStates)]
    else
        $scxml/(sc:state | sc:parallel | sc:final)
};

declare function analysis:getDescendantsAtLevelOrMBA($mba as element(),
        $level as xs:string,
        $toState as xs:string?
) as element()* {
    if ($mba/mba:topLevel[@name = $level]) then
        $mba
    else
        analysis:getDescendantsAtLevel($mba, $level, $toState)
};

(: for parsing function name out of transition condition :)
declare function analysis:parseFunction($cond as xs:string
) as xs:string {
    fn:substring-before($cond, "(")
};

(: for parsing level name out of transition condition :)
declare function analysis:parseLevelName($cond as xs:string
) as xs:string {
    fn:substring-before(fn:substring-after($cond, "'"), "'")
};

(: for parsing stateId out of transition condition :)
declare function analysis:parseStateId($cond as xs:string
) as xs:string {
    fn:substring-before(fn:substring-after(fn:substring-after($cond, ","), "'"), "'")
};

(: ### cancelled ### :)
declare function analysis:getActualAverageWIP($mba as element(),
        $level as xs:string,
        $function as function(element()) as xs:boolean
) as xs:decimal {
(: average number of instances of a process that are active at a given point in time :)
(: e.g. every day from 14:00 until 15:00 :)
    <TBD></TBD>
};

(: returns the average number of created instances in a given timeframe :)
(: e.g. every day from 14:00 to 15:00 :)
declare function analysis:getActualAverageLambda($mba as element(),
        $level as xs:string,
        $function as function(element()) as xs:boolean
) as xs:decimal {
    let $descendants := mba:getDescendantsAtLevel($mba, $level)

    return <TBD></TBD>
};

(: returns creation time of mba :)
declare function analysis:getCreationTime($mba as element()
) as xs:dateTime {
    xs:dateTime(analysis:getStateLog($mba)/state/@from[1])
};
