module namespace analysis = 'http://www.dke.jku.at/MBA/Analysis';

declare namespace xes = 'http://www.xes-standard.org/';

import module namespace mba = 'http://www.dke.jku.at/MBA' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/mba.xqm';
import module namespace sc = 'http://www.w3.org/2005/07/scxml' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/scxml.xqm';
import module namespace functx = 'http://www.functx.com' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/functx.xqm';
import module namespace tarjan = 'http://www.dke.jku.at/MBA/Tarjan' at 'C:/Users/manue/Masterarbeit/Analysis/tarjan.xqm';

(: returns total average cycle time of MBA at a certain level :)
declare function analysis:getTotalActualCycleTime($mba as element(),
        $level as xs:string,
        $toState as xs:string?
) as xs:duration? {
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
) as xs:duration? {
    let $stateLog := analysis:getStateLogToState($mba, $toState)/state

    let $cycleTimeOfInstance :=
        (if ($toState) then
            xs:dateTime($stateLog[last()]/@from)
        else if ($stateLog[last()]/@until) then
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
        $changedStates as element()?,
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
        $changedStates as element()?,
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
                analysis:getStateList($mba, $level, $inState, $source, $changedStates, $changedTransitions, $changedTransitionsFactors, $toState, ())
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
        $changedStates as element()?,
        $changedTransitions as element()*,
        $changedTransitionsFactors as xs:decimal*,
        $toState as xs:string,
        $sccRootNodes as element()*(: makes sure that a loop is not entered twice :)
) as element()* {
    let $scxml := analysis:getSCXMLAtLevel($mba, $level)

    let $cycleTime :=
        if (not(analysis:stateIsInitial($state))) then
            analysis:getCycleTimeForCompositeState($mba, $level, $inState, $state, $changedStates, $changedTransitions, $changedTransitionsFactors, $toState)
        else
            ()

    let $scc :=
        if (not(analysis:stateIsInitial($state))) then
            analysis:getSCCForRootNode($scxml, $state)
        else
            ()

    return
        (
            if (not(empty($cycleTime))) then
                element {'state'} {
                    $state/@id,
                    attribute averageCycleTime {$cycleTime}
                }
            else ()
            ,
            for $t in analysis:getTransitionsToState($scxml, $state, true(), true())
            return
                if (not(functx:is-node-in-sequence(sc:getSourceState($t), $sccRootNodes))) then (: source of transition is not in seq. $sccRootNodes :)
                    if (not(functx:is-node-in-sequence(sc:getSourceState($t), $scc))) then (: source of target not in scc :)
                        analysis:getStateList($mba, $level, $inState, sc:getSourceState($t), $changedStates, $changedTransitions, $changedTransitionsFactors, $toState, $sccRootNodes)
                    else
                    (: enter loop :)
                        let $sccRootNodes := ($sccRootNodes, analysis:getRootNodeOfSCC($scc)) (: add root node to $sccRootNodes :)
                        return
                            analysis:getStateList($mba, $level, $inState, sc:getSourceState($t), $changedStates, $changedTransitions, $changedTransitionsFactors, $toState, $sccRootNodes)
                else
                    ()(: no further investigation :)
        )
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
) as element()* {
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
        return
            <state id="{fn:string($state/@id)}">
                {
                    analysis:getCausesOfProblematicState($mba, $level, $state, $inState, $excludeArchiveStates, $threshold, $problematicStates, false())
                }
            </state>
};

(: checks what is causing $state to be problematic  :)
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
) as element()* {
    if (analysis:stateIsInitialOfSCXML($state) = true()) then (: initial state of scxml, end recursion :)
        <process level="{$level}"/>(:fn:concat("Process on level: '", $level, "'"):)
    else if (analysis:stateIsInitial($state) = true()) then
    (: call again for parent :)
        analysis:getCausesOfProblematicState($mba, $level, $state/.., $inState, $excludeArchiveStates, $threshold, $problematicStates, $checkSynchronizedProcess)
    else
        let $causes :=
            (
                analysis:getCausesOfProblematicSubstates($mba, $level, $state, $inState, $excludeArchiveStates, $threshold, $problematicStates)
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
                                        ($syncFunction = "$_isDescendantAtLevelInState") or
                                        ($syncFunction = "$_someDescendantAtLevelIsInState")) then (: "$_everyDescendantAtLevelIsInState('levelName', 'StateId')" :)
                                analysis:getCausesOfProblematicStateMBAAtLevelIsInState($mba, $level, $state, $excludeArchiveStates, $threshold, $syncFunction, $syncLevel, $syncStateId)
                            else if (
                                ($syncFunction = "$_ancestorAtLevelIsInState") or
                                        ($syncFunction = "$_isAncestorAtLevelInState")) then
                                analysis:getCausesOfProblematicStateAncestorAtLevelIsInState($mba, $level, $state, $excludeArchiveStates, $threshold, $syncFunction, $syncLevel, $syncStateId)
                            else
                                ()
                    else
                        () (: no cond --> no check needed for sync :)
                ,
                if ($checkSynchronizedProcess = true()) then
                (: follow process until initial/problematicState :)
                    analysis:getCauseOfProblematicSync($mba, $level, $state, $excludeArchiveStates, $threshold)
                else
                    ()
            )
        return
            $causes
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
) as element()* {
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
) as element()* {
    let $syncSCXML := analysis:getSCXMLAtLevel($mba, $syncLevel)
    let $syncState := $syncSCXML//(sc:state | sc:parallel | sc:final)[@id = $syncStateId]

    (: check if @until of problematic state is shortly after( within 5 minutes) @from of preceding state at least ONCE :)
    return
        if (analysis:isSyncCausingProblem($mba, $level, $state, $syncFunction, $syncLevel, $syncStateId) = true()) then
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
) as xs:boolean {
    let $descendants := analysis:getDescendantsAtLevelOrMBA($mba, $level, ())
    return (: for each descendant check if there is a problem with this sync :)
        functx:is-value-in-sequence(
                true()
                ,
                for $descendant in $descendants (: level of the problematic state itself :)
                let $stateLog := analysis:getStateLog($descendant)
                let $untilProblemState := $stateLog/state[@ref = $state/@id]/@until
                let $fromTimeSyncState := (: @from time(s) of sync level :)
                    if (($syncFunction = "$_ancestorAtLevelIsInState") or
                            ($syncFunction = "$_isAncestorAtLevelInState")) then
                        analysis:getFromTimeOfState(mba:getAncestorAtLevel($descendant, $syncLevel), $syncLevel, $syncStateId, $syncFunction)
                    else if ($syncFunction = "$_isDescendantAtLevelInState") then
                    (: descendant has to be in $syncState to trigger transition: all syncDescendants have to be checked :)
                        analysis:getAllFromTimes($descendant, $syncLevel, $syncStateId)
                    else (: descendants :)
                        analysis:getFromTimeOfState($descendant, $syncLevel, $syncStateId, $syncFunction)
                return
                    if (fn:empty($untilProblemState) or fn:empty($fromTimeSyncState)) then
                        false()
                    else
                        for $syncTime in $fromTimeSyncState
                        return analysis:timesAreSame($untilProblemState, $syncTime)
        )
};

(: follow process and until there is a problematic state :)
declare function analysis:getCauseOfProblematicSync($mba as element(),
        $level as xs:string,
        $state as element(), (: syncState :)
        $excludeArchiveStates as xs:boolean?,
        $threshold as xs:decimal?
) as element()* {
    let $scxml := analysis:getSCXMLAtLevel($mba, $level)
    let $syncProblematicStates := analysis:getProblematicStates($mba, $level, (), $excludeArchiveStates, $threshold)
    (: "$_everyDescendantAtLevelIsInState"/"$_someDescendantAtLevelIsInState"/"$_ancestorAtLevelIsInState": $state depends on preceding states of syncState  :)
    let $precedingStates := analysis:getTransitionsToState($scxml, $state, true(), true())/..
    return
        if ($precedingStates/@id = $syncProblematicStates/@id) then (: at least one $precedingState is problematic :)
            for $prec in $precedingStates[@id = $syncProblematicStates/@id] (: print all preceding problematic states :)
            return
                <state id="{fn:string($prec/@id)}">
                    {
                        analysis:getCausesOfProblematicState($mba, $level, $prec, (), $excludeArchiveStates, $threshold, $syncProblematicStates, false())
                    }
                </state>
        else
        (: follow process until a problematic state is found or initial :)
            for $prec in $precedingStates
            return
                analysis:getCausesOfProblematicState($mba, $level, $prec, (), $excludeArchiveStates, $threshold, $syncProblematicStates, true())
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
        else if (($syncFunction = "$_ancestorAtLevelIsInState") or
                    ($syncFunction = "$_isAncestorAtLevelInState")) then
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
declare function analysis:getCausesOfProblematicSubstates($mba as element(),
        $level as xs:string,
        $state as element(),
        $inState as xs:string?,
        $excludeArchiveStates as xs:boolean?,
        $threshold as xs:decimal?,
        $problematicStates as element()*
) as element()* {
    let $substates := $state//(sc:state | sc:parallel | sc:final)
    return
        if ($problematicStates/@id = $substates/@id) then (: check substates: if true at least one $substate is problematic :)
            for $sub in $substates[@id = $problematicStates/@id] (: print all problematic substates :)
            return
                <state id="{fn:string($sub/@id)}">
                    {
                        analysis:getCausesOfProblematicState($mba, $level, $sub, $inState, $excludeArchiveStates, $threshold, $problematicStates, false())
                    }
                </state>
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
) as xs:boolean {
    if (($time2 <= $time1) and ($time1 - $time2 <= xs:dayTimeDuration("PT5M"))) then
        true()
    else
        false()
};

declare function analysis:getCycleTimeForCompositeState($mba as element(),
        $level as xs:string,
        $inState as xs:string?,
        $state as element(),
        $changedStates as element()?,
        $changedTransitions as element()*,
        $changedTransitionsFactors as xs:decimal*,
        $toState as xs:string?
) as xs:duration? {
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
            analysis:getAverageCycleTime($mba, $level, $inState, $state/@id(:, $toState:)) *
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

        let $scc := analysis:getSCCForRootNode($scxml, $state)
        return
            if (empty($scc)) then (: no loop :)
                fn:sum(
                        for $transition in $transitions
                        return
                            (
                                (
                                    if (not(analysis:transitionInChangedTransitions($transition, $changedTransitions))) then
                                        analysis:getTransitionProbability($transition, $toState)
                                    else
                                        $changedTransitionsFactors[position() = functx:index-of-node($changedTransitions, $transition)]
                                )
                                        * analysis:getTransitionProbabilityForTargetState($scxml, sc:getSourceState($transition), $changedTransitions, $changedTransitionsFactors, $toState, true(), true()))
                        ,
                        0
                )
            else
                analysis:getProbabilityForRootNode($scxml, $scc, $toState) (: probability for root node of strongly connected components :)
                        * fn:sum(
                        for $transition in $transitions
                        return
                            if (not(functx:is-node-in-sequence(sc:getSourceState($transition), $scc))) then (: only states which are not in scc :)
                                analysis:getTransitionProbability($transition, $toState)
                                        * analysis:getTransitionProbabilityForTargetState($scxml, sc:getSourceState($transition), $changedTransitions, $changedTransitionsFactors, $toState, true(), true())
                            else
                                ()
                        ,
                        0
                )
(:
            Solutions for rework loops:
                1. search for strongly connected components
                2. each scc has a root node(last state in map entry) --> start of rework loop!
                    a. Probability of root node is [1/(1-r)]
                    b. r = Probability of path leaving root node which goes back to root node
                    c. If there are multiple paths to root node, sum up
        :)
};

(: returns strongly connected components if $state is root node. Empty if $state is no root of a scc :)
declare function analysis:getSCCForRootNode($scxml as element(),
        $state as element()
) as element()* {
    let $sccMap := analysis:tarjanAlgorithm($scxml)
    let $scc := fn:for-each(
            map:keys($sccMap),
            function($k){
                let $entry := map:get($sccMap, $k)
                return
                    if (analysis:getRootNodeOfSCC($entry) is $state) then
                        $entry
                    else
                        ()
            }
    )
    return $scc
};

declare function analysis:getProbabilityForRootNode($scxml as element(),
        $scc as element()*,
        $toState as xs:string?
) as xs:decimal {
    let $r :=
        fn:sum(
                for $t in analysis:getTransitionsToState($scxml, analysis:getRootNodeOfSCC($scc), true(), true())
                return
                    if (functx:is-node-in-sequence(sc:getSourceState($t), $scc)) then
                        analysis:getTransitionProbability($t, $toState) *
                                analysis:getR($scxml, $scc, $toState, sc:getSourceState($t))
                    else
                        0(: source of $t is not in scc :)
        )

    return 1 div (1 - $r)
};

declare function analysis:getR($scxml as element(),
        $scc as element()*,
        $toState as xs:string?,
        $state as element()
) as xs:decimal {
    if ($state is analysis:getRootNodeOfSCC($scc)) then
        1
    else
        fn:sum(
                for $t in analysis:getTransitionsToState($scxml, $state, true(), true())
                return
                    if (functx:is-node-in-sequence(sc:getSourceState($t), $scc)) then
                        analysis:getTransitionProbability($t, $toState) *
                                analysis:getR($scxml, $scc, $toState, sc:getSourceState($t))
                    else
                        0(: source of $t is not in scc :)
        )
};

declare function analysis:getRootNodeOfSCC($scc as element()*
) as element() {
    $scc[last()]
};

(: returns true if a $transition is in a sequence of $changedTransitions, based on node identity :)
declare function analysis:transitionInChangedTransitions($transition as element(),
        $changedTransitions as element()*
) as xs:boolean {
    functx:is-node-in-sequence($transition, $changedTransitions)
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
declare function analysis:getAverageCycleTime($mba as element(),
        $level as xs:string,
        $inState as xs:string?,
        $stateId as xs:string(:,
        $toState as xs:string?:)
) as xs:duration? {
    let $descendants := (: if the topLevel is $level, analyze $mba :)
        (
            if ($mba/mba:topLevel[@name = $level]) then
                $mba
            else
                mba:getDescendantsAtLevel($mba, $level)
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
        $states as xs:string*
) as xs:duration? {
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
) as xs:boolean {
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
            element {fn:node-name($stateLog)} {$stateLog/state[@ref = $toState]/(self::state | preceding-sibling::state)}
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

(: returns creation time of mba :)
declare function analysis:getCreationTime($mba as element()
) as xs:dateTime {
    xs:dateTime(analysis:getStateLog($mba)/state/@from[1])
};

(: ### Tarjan Algorithm ### :)
(: returns map of scc's, loops are from first to last state in map entry :)
declare function analysis:tarjanAlgorithm($scxml as element()
) as map(*) {
    let $scc :=
        map:get(
                fn:fold-left($scxml//(sc:state | sc:parallel | sc:final),
                        analysis:createMap(0, (), (), (), ()),
                        function($result, $state) {
                            let $index := map:get($result, 'index')
                            let $indexes := map:merge(map:get($result, 'indexes'))
                            let $lowlinks := map:merge(map:get($result, 'lowlinks'))
                            let $stack := map:get($result, 'stack')
                            let $scc := map:get($result, 'scc')

                            return
                                if (analysis:notVisited($indexes, $state/@id)) then
                                    analysis:strongconnect($scxml, $state, $result)
                                else
                                    $result
                        }),
                'scc'
        )

    return (: remove scc's which only consist of one state :)
        map:merge((
            for $s in 0 to (map:size($scc) - 1)
            let $item := map:get($scc, $s)
            return
                if (fn:count($item) > 1) then
                    map:entry($s, $item)
                else
                    ()
        ))
};

declare function analysis:strongconnect($scxml as element(),
        $state as element(),
        $resultMap as map(*)
) as map(*) {
    let $index := map:get($resultMap, 'index') (: next index :)
    let $indexes := map:merge((map:get($resultMap, 'indexes'), map:entry($state/@id, $index)))
    let $lowlink := $index
    let $lowlinks := map:merge(((map:get($resultMap, 'lowlinks'), map:entry($state/@id, $lowlink))))

    let $stack := (map:get($resultMap, 'stack'), $state) (: push :)
    let $scc := map:get($resultMap, 'scc')

    let $index := $index + 1

    (: consider successors of $state :)
    let $successors := analysis:getSuccessors($scxml, $state/@id)

    let $recursiveResult :=
        fn:fold-left($successors,
                analysis:createMap($index, $indexes, $lowlinks, $stack, $scc),
                function($result, $successor) {
                    if (analysis:notVisited($indexes, $successor/@id)) then
                    (: $successor has not yet been visited; recurse on it :)
                        let $sucResult := analysis:strongconnect($scxml, $successor, $result)
                        (: min($state.lowlink, $successor.lowlink) :)
                        let $lowlinks := map:get($sucResult, 'lowlinks')
                        let $lowlink := min((
                            map:get($lowlinks, $state/@id),
                            map:get($lowlinks, $successor/@id)
                        ))
                        return
                            analysis:createMap(map:get($sucResult, 'index'),
                                    map:get($sucResult, 'indexes'),
                                    map:merge((($lowlinks, map:entry($state/@id, $lowlink)))),
                                    map:get($sucResult, 'stack'),
                                    map:get($sucResult, 'scc')
                            )
                    else if (analysis:onStack($stack, $successor)) then
                    (: $successor is in stack and hence in the current SCC :)
                        let $indexes := map:get($result, 'indexes')
                        let $lowlinks := map:get($result, 'lowlinks')
                        let $lowlink := min((
                            map:get($lowlinks, $state/@id),
                            map:get($indexes, $successor/@id)
                        ))
                        return
                            analysis:createMap(
                                    map:get($result, 'index'),
                                    map:get($result, 'indexes'),
                                    map:merge((($lowlinks, map:entry($state/@id, $lowlink)))),
                                    map:get($result, 'stack'),
                                    map:get($result, 'scc')
                            )
                    else
                        $result
                }
        )

    let $index := map:get($recursiveResult, 'index')
    let $indexes := map:get($recursiveResult, 'indexes')
    let $lowlinks := map:get($recursiveResult, 'lowlinks')
    let $stack := map:get($recursiveResult, 'stack')
    let $scc := map:merge(map:get($recursiveResult, 'scc'))

    return
    (: if $lowlink = $index (i.e. $state is a root node), return SCC and pop from stack :)
        if (map:get($lowlinks, $state/@id) = map:get($indexes, $state/@id)) then
            let $map := analysis:popStack($stack, (), $state)
            let $newStack := map:get($map, 'stack')
            let $newScc := map:get($map, 'scc')
            return
                analysis:createMap($index, $indexes, $lowlinks, $newStack, map:merge(($scc, map:entry(map:size($scc), $newScc))))
        else
            analysis:createMap($index, $indexes, $lowlinks, $stack, $scc)
};

declare function analysis:createMap($index as xs:integer, (: global index :)
        $indexes as map(*)?, (: mapping of state to index :)
        $lowlinks as map(*)?, (: mapping of state to lowlinks :)
        $stack as element()*, (: sequence which simulates stack :)
        $scc as map(*)?(: strongly connected components :)
) as map(*) {
    map:merge((
        map:entry('index', $index),
        map:entry('indexes', $indexes),
        map:entry('lowlinks', $lowlinks),
        map:entry('stack', $stack),
        map:entry('scc', $scc)
    ))
};

declare function analysis:notVisited($indexes as map(*),
        $state as xs:string
) as xs:boolean {
    fn:empty(map:get($indexes, $state))
};

declare function analysis:onStack($stack as element()*,
        $state as element()
) as xs:boolean {
    functx:is-node-in-sequence($state, $stack)
};

declare function analysis:popStack($stack as element()*,
        $scc as element()*,
        $state as element()
) as map(*) {
(: pop until $stack.pop = $state :)
    let $s := $stack[last()]
    let $stack := $stack[position() != last()]
    let $scc := ($scc, $s)

    return
        if ($s is $state) then
            map:merge((
                map:entry('stack', $stack),
                map:entry('scc', $scc)
            ))
        else
            analysis:popStack($stack, $scc, $state)
};

declare function analysis:getSuccessors($scxml as element(),
        $state as xs:string
) as element()* {
    $scxml//(sc:state | sc:parallel | sc:final)[@id = analysis:getTransitionsLeavingState($scxml, $state)/@target]
};

declare function analysis:getTransitionsLeavingState($scxml as element(),
        $state as xs:string
) as element()* {
    $scxml//(sc:state | sc:parallel | sc:final)[@id = $state]//sc:transition[analysis:stateIsLeft(., $state)]
};