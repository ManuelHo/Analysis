module namespace analysis = 'http://www.dke.jku.at/MBA/Analysis';

declare namespace xes = 'http://www.xes-standard.org/';

import module namespace mba = 'http://www.dke.jku.at/MBA';
import module namespace sc = 'http://www.w3.org/2005/07/scxml';
import module namespace functx = 'http://www.functx.com';

(:~ 
 : This function returns the cycle time of a MBA until a given state is reached.
 : @param $mba investigated MBA
 : @param $level level of process
 : @param $toState time is calculated until this state is reached
 : @return cycle time until given state is reached
 :)
declare function analysis:getTotalActualCycleTime(
        $mba as element(),
        $level as xs:string,
        $toState as xs:string?
) as xs:duration? {
    let $descendants :=
        analysis:getDescendantsAtLevelOrMBA($mba, $level, $toState)

    let $cycleTimes :=
        for $descendant in $descendants
        return analysis:getCycleTimeOfInstance($descendant, $toState)

    return fn:avg($cycleTimes)
};

(:~ 
 : This function returns the cycle time of a MBA's top level until a given state
 : is reached.
 : @param $mba investigated MBA
 : @param $toState time is calculated until this state is reached
 : @return cycle time until given state is reached
 :)
declare function analysis:getCycleTimeOfInstance(
        $mba as element(),
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
        ) - xs:dateTime(($stateLog[1]/@from))

    return $cycleTimeOfInstance
};

(:~ 
 : This function returns the cycle time of a MBA with the option to change cycle
 : times of states and transition probabilities.
 : @param $mba investigated MBA
 : @param $level level of process
 : @param $inState only MBAs which are in this state are considered
 : @param $excludeArchiveStates option to exclude archive states
 : @param $changedStates states, which cycle times are changed
 : @param $changedTransitions transitions, which probability is changed
 : @param $changedTransitionsFactors new probabilities of changed transitions
 : @return cycle time of MBA
 :)
declare function analysis:getTotalCycleTime(
        $mba as element(),
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
                for $state in $states
                return
                    analysis:getCycleTimeForCompositeState($mba, $level, $inState, $state, $changedStates, $changedTransitions, $changedTransitionsFactors)
        )
};

(:~ 
 : This function returns the cycle time of a MBA until a given state is reached
 : with the option to change cycle times of states and transition probabilities.
 : @param $mba investigated MBA
 : @param $level level of process
 : @param $inState only MBAs which are in this state are considered
 : @param $toState time is calculated until this state is reached
 : @param $changedStates states, which cycle times are changed
 : @param $changedTransitions transitions, which probability is changed
 : @param $changedTransitionsFactors new probabilities of changed transitions
 : @return cycle time of MBA
 :)
declare function analysis:getTotalCycleTimeToState(
        $mba as element(),
        $level as xs:string,
        $inState as xs:string?,
        $toState as xs:string,
        $changedStates as element()?,
        $changedTransitions as element()*,
        $changedTransitionsFactors as xs:decimal*
) as xs:duration {
    let $scxml := analysis:getSCXMLAtLevel($mba, $level)
    let $state := $scxml//*[@id = $toState]
    (: check if $toState is root-node of scc, if yes do not follow transitions to root node which start from states in loop :)
    let $sccMap := analysis:tarjanAlgorithm($scxml)
    let $scc := (: if $toState is not in a scc, this is empty :)
        fn:for-each(
                map:keys($sccMap),
                function($k){
                    if (functx:is-node-in-sequence($state, map:get($sccMap, $k))) then
                        map:get($sccMap, $k)
                    else
                        ()
                }
        )
    let $stateList := analysis:getStateList($mba, $level, $inState, $state, $changedStates, $changedTransitions, $changedTransitionsFactors, $toState, $scc, ())

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

 (:~ 
 : This function returns a list of distinct state elements which can appear in a
 : process before a given state. The elements contain their weighed cycle times.
 : @param $mba investigated MBA
 : @param $level level of process
 : @param $inState only MBAs which are in this state are considered
 : @param $state state
 : @param $changedStates states, which cycle times are changed
 : @param $changedTransitions transitions, which probability is changed
 : @param $changedTransitionsFactors new probabilities of changed transitions
 : @param $toState time is calculated until this state is reached
 : @param $scc strongly connected component whith state as root
 : @param $stateList already calculated states
 : @return list of state elements
 :)
declare function analysis:getStateList(
        $mba as element(),
        $level as xs:string,
        $inState as xs:string?,
        $state as element(),
        $changedStates as element()?,
        $changedTransitions as element()*,
        $changedTransitionsFactors as xs:decimal*,
        $toState as xs:string,
        $scc as element()*,
        $stateList as element()*
) as element()* {
    if (not($stateList[@id = $state/@id])) then (: entered if initial(=no @id) or not entry for $state in $stateList :)
        let $cycleTime :=
            if (not(analysis:stateIsInitial($state)) and fn:compare($state/@id, $toState) != 0) then (: if $toState, no calc. :)
                analysis:getCycleTimeForCompositeState($mba, $level, $inState, $state, $changedStates, $changedTransitions, $changedTransitionsFactors)
            else
                ()

        let $entry :=
            if (not(empty($cycleTime))) then
                element {'state'} {
                    $state/@id,
                    attribute averageCycleTime {$cycleTime}
                }
            else ()
        let $stateList := ($stateList, $entry) (: if $toState or initial, $entry is empty :)

        let $scxml := analysis:getSCXMLAtLevel($mba, $level)
        let $transitions :=
            let $t := analysis:getTransitionsToState($scxml, $state)
            return
                if ($scc and ($state is analysis:getRootNodeOfSCC($scc))) then (: special treatment for loops. needed if $toState is in scc :)
                (: if $toState is in $scc and $state is the root node of it, remove all transitions which enter loop :)
                    $t[not(functx:is-node-in-sequence(sc:getSourceState(.), $scc))]
                else
                    $t
        return
            fn:fold-left($transitions, $stateList,
                    function($result, $t) {
                        let $source := sc:getSourceState($t)
                        return
                            analysis:getStateList($mba, $level, $inState, $source, $changedStates, $changedTransitions, $changedTransitionsFactors, $toState, $scc, $result)
                    }
            )
    else
        $stateList(: state already in result list :)
};

(:~ 
 : This function returns all states of a MBA which cycle time exceeds a given
 : threshold.
 : @param $mba investigated MBA
 : @param $level level of process
 : @param $inState only MBAs which are in this state are considered
 : @param $excludeArchiveStates option to exclude archive states
 : @param $threshold defines max allowed cycle time as fraction of total cycle
 :        time
 : @return problematic states
 :)
declare function analysis:getProblematicStates(
        $mba as element(),
        $level as xs:string,
        $inState as xs:string?,
        $excludeArchiveStates as xs:boolean?,
        $threshold as xs:decimal
) as element()* {
    let $totalCycleTime := analysis:getTotalCycleTime($mba, $level, $inState, $excludeArchiveStates, (), (), ())
    let $cycleTimeThreshold := $totalCycleTime * $threshold

    let $scxml := analysis:getSCXMLAtLevel($mba, $level)
    let $states := analysis:getStates($scxml, $excludeArchiveStates)

    return
        for $state in $states
        let $cycleTime := analysis:getCycleTimeForCompositeState($mba, $level, $inState, $state, (), (), ())
        return
            if ($cycleTime >= $cycleTimeThreshold) then
                $state
            else
                ()
};

(:~ 
 : This function identifies the causes of problematic states.
 : If there is a substate which is also problematic AND ends at the same time as
 : the state, the substate is the bottleneck.
 : If there is a multilevel synchronization dependency: check if there is a
 : problematic state which causes the bottleneck.
 : @param $mba investigated MBA
 : @param $level level of process
 : @param $inState only MBAs which are in this state are considered
 : @param $excludeArchiveStates option to exclude archive states
 : @param $threshold defines max allowed cycle time as fraction of total cycle
 :        time
 : @param $difference max duration between two correlating events
 : @return causes of problematic states
 :)
declare function analysis:getCausesOfProblematicStates(
        $mba as element(),
        $level as xs:string,
        $inState as xs:string?,
        $excludeArchiveStates as xs:boolean?,
        $threshold as xs:decimal,
        $difference as xs:dayTimeDuration?
) as element()* {
    let $problematicStates := analysis:getProblematicStates($mba, $level, $inState, $excludeArchiveStates, $threshold)

    return
        for $state in $problematicStates
        return
            <state id="{fn:string($state/@id)}">
                {
                    analysis:getCausesOfProblematicState($mba, $level, $state, $inState, $excludeArchiveStates, $threshold, $problematicStates, false(), $difference)
                }
            </state>
};

(:~ 
 : This function identifies the causes of a single problematic state.
 : @param $mba investigated MBA
 : @param $level level of process
 : @param $state state
 : @param $inState only MBAs which are in this state are considered
 : @param $excludeArchiveStates option to exclude archive states
 : @param $threshold defines max allowed cycle time as fraction of total cycle
 :        time
 : @param $problematicStates all problematic states of process
 : @param $checkPrecedingStates true if function was called from path of
 :        sychnronized process
 : @param $difference max duration between two correlating events
 : @return causes of problematic state
 :)
declare function analysis:getCausesOfProblematicState(
        $mba as element(),
        $level as xs:string,
        $state as element(),
        $inState as xs:string?,
        $excludeArchiveStates as xs:boolean?,
        $threshold as xs:decimal?,
        $problematicStates as element()*,
        $checkPrecedingStates as xs:boolean,
        $difference as xs:dayTimeDuration?
) as element()* {
    if (analysis:stateIsInitialOfSCXML($state) = true()) then
        <process level="{$level}"/>
    else if (analysis:stateIsInitial($state) = true()) then
        analysis:getCausesOfProblematicState($mba, $level, $state/.., $inState, $excludeArchiveStates, $threshold, $problematicStates, $checkPrecedingStates, $difference)
    else
        (
            analysis:getProblematicSubstates($mba, $level, $state, $inState, $excludeArchiveStates, $threshold, $problematicStates, $difference)
            ,
            analysis:getProblematicSyncs($mba, $level, $state, $excludeArchiveStates, $threshold, $difference)
            ,
            if ($checkPrecedingStates = true()) then
                (: follow process until initial/problematicState :)
                analysis:getCauseOfProblematicSync($mba, $level, $state, $excludeArchiveStates, $threshold, $difference)
            else
                ()
        )
};

(:~ 
 : This function identifies the causes of a single problematic state by
 : investigating synchronization dependencies.
 : @param $mba investigated MBA
 : @param $level level of process
 : @param $state state
 : @param $excludeArchiveStates option to exclude archive states
 : @param $threshold defines max allowed cycle time as fraction of total cycle
 :        time
 : @param $difference max duration between two correlating events
 : @return causes of problematic state
 :)
declare function analysis:getProblematicSyncs(
        $mba as element(),
        $level as xs:string,
        $state as element(),
        $excludeArchiveStates as xs:boolean?,
        $threshold as xs:decimal?,
        $difference as xs:dayTimeDuration?
) as element()* {
    for $t in analysis:getTransitionsLeavingState(analysis:getSCXMLAtLevel($mba, $level), $state/@id)
    return
        if ($t/@cond) then
            let $syncFunction := analysis:parseFunction($t/@cond)
            return
                if (($syncFunction = "$_everyDescendantAtLevelIsInState") or
                        ($syncFunction = "$_someDescendantAtLevelIsInState") or
                        ($syncFunction = "$_ancestorAtLevelIsInState")) then (: "$_everyDescendantAtLevelIsInState('levelName', 'StateId')" :)
                    analysis:getProblematicSyncsMBAAtLevelIsInState($mba, $level, $state,
                            $excludeArchiveStates, $threshold, $syncFunction,
                            analysis:parseLevelTwoParams($t/@cond),
                            analysis:parseStateTwoParams($t/@cond), (), $difference)
                else if (($syncFunction = "$_isDescendantAtLevelInState") or
                        ($syncFunction = "$_isAncestorAtLevelInState")) then (: three params :)
                    analysis:getProblematicSyncsMBAAtLevelIsInState($mba, $level, $state,
                            $excludeArchiveStates, $threshold, $syncFunction,
                            analysis:parseLevelThreeParams($t/@cond),
                            analysis:parseStateThreeParams($t/@cond),
                            analysis:parseObjectThreeParams($t/@cond),
                            $difference)
                else
                    ()
        else
            ()(: no cond --> no check needed for sync :)
};

(:~ 
 : This function identifies the causes of a single problematic state by
 : investigating a specific synchronization dependency.
 : @param $mba investigated MBA
 : @param $level level of process
 : @param $state state
 : @param $excludeArchiveStates option to exclude archive states
 : @param $threshold defines max allowed cycle time as fraction of total cycle
 :        time
 : @param $syncFunction function used in sync dependency
 : @param $syncLevel level which is referenced in sync dependency
 : @param $syncStateId state which is ferenced in sync dependency
 : @param $syncObj object which is referenced in sync dependency
 : @param $difference max duration between two correlating events
 : @return causes of problematic state
 :)
declare function analysis:getProblematicSyncsMBAAtLevelIsInState(
        $mba as element(),
        $level as xs:string,
        $state as element(),
        $excludeArchiveStates as xs:boolean?,
        $threshold as xs:decimal?,
        $syncFunction as xs:string,
        $syncLevel as xs:string,
        $syncStateId as xs:string,
        $syncObj as xs:string?,
        $difference as xs:dayTimeDuration?
) as element()* {
    let $mba := (: checks if the $mba contains a scxml element for $syncLevel. If not, it replaces $mba with its ancestor at $syncLevel. :)
        if (
            (($syncFunction = "$_ancestorAtLevelIsInState") or
                    ($syncFunction = "$_isAncestorAtLevelInState")
            ) and not(analysis:getSCXMLAtLevel($mba, $syncLevel))
        ) then
            mba:getAncestorAtLevel($mba, $syncLevel)
        else
            $mba

    let $syncSCXML := analysis:getSCXMLAtLevel($mba, $syncLevel)
    let $syncState := analysis:getState($syncSCXML, $syncStateId)

    return
        if (analysis:isSyncCausingProblem($mba, $level, $state, $syncFunction, $syncLevel, $syncStateId, $syncObj, $difference)) then
            analysis:getCauseOfProblematicSync($mba, $syncLevel, $syncState, $excludeArchiveStates, $threshold, $difference)
        else
            ()(: time is totally different, $state is not delayed by sync :)
};

(:~ 
 : This function checks if a problematic state is caused by a specific
 : synchronization dependency. This is the case if @until of problematic state
 : is shortly after (within five minutes) @from of referenced state at least
 : once.
 : @param $mba investigated MBA
 : @param $level level of process
 : @param $state state
 : @param $syncFunction function used in sync dependency
 : @param $syncLevel level which is referenced in sync dependency
 : @param $syncStateId state which is ferenced in sync dependency
 : @param $syncObj object which is referenced in sync dependency
 : @param $difference max duration between two correlating events
 : @return causes of problematic state
 :)
declare function analysis:isSyncCausingProblem(
        $mba as element(),
        $level as xs:string,
        $state as element(),
        $syncFunction as xs:string,
        $syncLevel as xs:string,
        $syncStateId as xs:string,
        $syncObj as xs:string?,
        $difference as xs:dayTimeDuration?
) as xs:boolean {
    let $descendants := analysis:getDescendantsAtLevelOrMBA($mba, $level)
    return (: for each descendant check if there is a problem with this sync :)
        functx:is-value-in-sequence(
                true()
                ,
                for $descendant in $descendants (: level of the problematic state itself :)
                let $stateLog := analysis:getStateLog($descendant)
                let $untilProblemState := $stateLog/state[@ref = $state/@id]/@until (: may be more than one when process contains loops :)
                let $fromTimeSyncState := (: @from time(s) of sync level :)
                    if ($syncFunction = "$_everyDescendantAtLevelIsInState") then
                        analysis:getMaxFromTimeOfState($descendant, $syncLevel, $syncStateId, $untilProblemState)
                    else if ($syncFunction = "$_someDescendantAtLevelIsInState") then
                        analysis:getMinFromTimeOfState($descendant, $syncLevel, $syncStateId, $untilProblemState)
                    else if ($syncFunction = "$_isDescendantAtLevelInState") then (: get @from times of $syncObj :)
                            analysis:getAllFromTimesOfState(xquery:eval($syncObj), $syncStateId)
                        else if ($syncFunction = "$_ancestorAtLevelIsInState") then (: ancestor has to be in state to trigger, check all @from times (because loops) :)
                                analysis:getAllFromTimesOfState(mba:getAncestorAtLevel($descendant, $syncLevel), $syncLevel, $syncStateId)
                            else if ($syncFunction = "$_isAncestorAtLevelInState") then (: get @from times of $syncObj :)
                                    analysis:getAllFromTimesOfState(xquery:eval($syncObj), $syncStateId)
                                else
                                    ()
                return
                    if (fn:empty($untilProblemState) or fn:empty($fromTimeSyncState)) then
                        false()
                    else
                        for $untilTime in $untilProblemState
                        return
                            for $syncTime in $fromTimeSyncState
                            return analysis:timesAreSame($untilTime, $syncTime, $difference)
        )
};

(:~ 
 : This function identifies the causes of a problematic state which is caused by
 : a specific synchronization dependency.
 : @param $mba investigated MBA
 : @param $level level of process
 : @param $state state
 : @param $excludeArchiveStates option to exclude archive states
 : @param $threshold defines max allowed cycle time as fraction of total cycle
 :        time
 : @param $difference max duration between two correlating events
 : @return causes of problematic state
 :)
declare function analysis:getCauseOfProblematicSync(
        $mba as element(),
        $level as xs:string,
        $state as element(), (: syncState :)
        $excludeArchiveStates as xs:boolean?,
        $threshold as xs:decimal?,
        $difference as xs:dayTimeDuration?
) as element()* {
    let $scxml := analysis:getSCXMLAtLevel($mba, $level)
    let $problematicStates := analysis:getProblematicStates($mba, $level, (), $excludeArchiveStates, $threshold)
    (: "$_everyDescendantAtLevelIsInState"/"$_someDescendantAtLevelIsInState"/"$_ancestorAtLevelIsInState": $state depends on preceding states of syncState  :)
    let $precedingStates := analysis:getTransitionsToState($scxml, $state)/..
    return
        if ($precedingStates/@id = $problematicStates/@id) then
            for $prec in $precedingStates[@id = $problematicStates/@id]
            return
                <state id="{fn:string($prec/@id)}">
                    {
                        analysis:getCausesOfProblematicState($mba, $level, $prec, (), $excludeArchiveStates, $threshold, $problematicStates, false(), $difference)
                    }
                </state>
        else
        (: follow process until a problematic state is found or initial :)
            functx:distinct-deep(
                    for $prec in $precedingStates
                    return (: call of this function allows to check further synchronization dependencies :)
                        analysis:getCausesOfProblematicState($mba, $level, $prec, (), $excludeArchiveStates, $threshold, $problematicStates, true(), $difference)
            )
};

(:~ 
 : This function returns the max from attribute of a given state from all
 : descendants which have been in state at given timestamp.
 : @param $mba investigated MBA
 : @param $level level of process
 : @param $state state
 : @param $timestamp timestamp
 : @return max from attribute
 :)
declare function analysis:getMaxFromTimeOfState(
        $mba as element(),
        $level as xs:string,
        $state as xs:string,
        $timestamp as xs:dateTime*
) as xs:dateTime* {
    let $fromTimes := analysis:getRelevantFromTimes($mba, $level, $state, $timestamp)
    return
        max(
                for $d in $fromTimes
                return xs:dateTime($d)
        )
};

(:~ 
 : This function returns the min from attribute of a given state from all
 : descendants which have been in state at given timestamp.
 : @param $mba investigated MBA
 : @param $level level of process
 : @param $state state
 : @param $timestamp timestamp
 : @return min from attribute
 :)
declare function analysis:getMinFromTimeOfState(
        $mba as element(),
        $level as xs:string,
        $state as xs:string,
        $timestamp as xs:dateTime*
) as xs:dateTime* {
    let $fromTimes := analysis:getRelevantFromTimes($mba, $level, $state, $timestamp)
    return
        min(
                for $d in $fromTimes
                return xs:dateTime($d)
        )
};

(:~ 
 : This function returns all from attributes of a given state from all
 : descendants.
 : @param $mba investigated MBA
 : @param $level level of process
 : @param $state state
 : @return from attributes
 :)
declare function analysis:getAllFromTimesOfState(
        $mba as element(),
        $level as xs:string,
        $state as xs:string
) as xs:dateTime* {
    for $descendant in analysis:getDescendantsAtLevelOrMBA($mba, $level)
    let $subStateLog := analysis:getStateLog($descendant)
    return xs:dateTime($subStateLog/state[@ref = $state]/@from)
};

(:~ 
 : This function returns all from attributes of a given state from a given MBA.
 : @param $mba investigated MBA
 : @param $state state
 : @return from attributes
 :)
declare function analysis:getAllFromTimesOfState(
        $mba as element(),
        $state as xs:string
) as xs:dateTime* {
    let $subStateLog := analysis:getStateLog($mba)
    return xs:dateTime($subStateLog/state[@ref = $state]/@from)
};

(:~ 
 : This function returns all from attributes of a given state from all
 : descendants. Only states which have been active at a given timestamp are
 : considered.
 : @param $mba investigated MBA
 : @param $level level of process
 : @param $state state
 : @param $timestamp timestamp
 : @return from attributes
 :)
declare function analysis:getRelevantFromTimes(
        $mba as element(),
        $level as xs:string,
        $state as xs:string,
        $timestamp as xs:dateTime*
) as xs:dateTime* {
    let $descendants := analysis:getDescendantsAtLevelOrMBA($mba, $level)
    return
        for $descendant in $descendants
        let $stateLog := analysis:getStateLog($descendant)
        return
            functx:distinct-deep(
                    for $stamp in $timestamp
                    return
                        $stateLog//*[@ref = $state and @from <= $stamp and functx:if-empty(@until, current-dateTime()) >= $stamp]
            )/@from
};

(:~ 
 : This function checks if a problematic state is caused by a substate.
 : @param $mba investigated MBA
 : @param $level level of process
 : @param $state state
 : @param $inState only MBAs which are in this state are considered
 : @param $excludeArchiveStates option to exclude archive states
 : @param $threshold defines max allowed cycle time as fraction of total cycle
 :        time
 : @param $problematicStates all problematic states of process
 : @param $difference max duration between two correlating events
 : @return causes of problematic state
 :)
declare function analysis:getProblematicSubstates(
        $mba as element(),
        $level as xs:string,
        $state as element(),
        $inState as xs:string?,
        $excludeArchiveStates as xs:boolean?,
        $threshold as xs:decimal?,
        $problematicStates as element()*,
        $difference as xs:dayTimeDuration?
) as element()* {
    let $substates := $state//(sc:state | sc:parallel | sc:final)
    return
        if ($problematicStates/@id = $substates/@id) then
            for $sub in $substates[@id = $problematicStates/@id]
            return
                <state id="{fn:string($sub/@id)}">
                    {
                        analysis:getCausesOfProblematicState($mba, $level, $sub, $inState, $excludeArchiveStates, $threshold, $problematicStates, false(), $difference)
                    }
                </state>
        else
            ()
};

(:~ 
 : This function checks if a state is an initial state.
 : @param $state state
 : @return true if state is initial
 :)
declare function analysis:stateIsInitial(
        $state as element()
) as xs:boolean {
    (fn:compare(fn:name($state), 'sc:initial') = 0)
};

(:~ 
 : This function checks if a state is the initial state of the process model.
 : @param $state state
 : @return true if state is initial of scxml
 :)
declare function analysis:stateIsInitialOfSCXML(
        $state as element()
) as xs:boolean {
    (fn:compare(fn:name($state), 'sc:initial') = 0) and
            (fn:compare(fn:name($state/..), 'sc:scxml') = 0)
};

(:~ 
 : This function checks if a state is a child of a parallel element.
 : @param $state state
 : @return true if state is child of parallel element
 :)
declare function analysis:parentIsParallel(
        $state as element()
) as xs:boolean {
    (fn:compare(fn:name($state/..), 'sc:parallel') = 0)
};

(:~ 
 : This function checks if a state is a parallel element.
 : @param $state state
 : @return true if state is a parallel element
 :)
declare function analysis:isParallel(
        $state as element()
) as xs:boolean {
    fn:compare(fn:name($state), 'sc:parallel') = 0
};

(:~ 
 : This function checks if a timestamp is within a given difference after a second
 : timestamp.
 : @param $time1 first timestamp
 : @param $time2 second timestamp
 : @param $difference max difference between timestamps
 : @return true if first timestamp is within 5 minutes after second timestamp
 :)
declare function analysis:timesAreSame(
        $time1 as xs:dateTime,
        $time2 as xs:dateTime,
        $difference as xs:dayTimeDuration?
) as xs:boolean {
    let $difference :=
        if (empty($difference)) then
            $difference
        else
            xs:dayTimeDuration("PT5M")
    return
        if (($time2 <= $time1) and ($time1 - $time2 <= $difference)) then
            true()
        else
            false()
};

(:~ 
 : This function returns the cycle time of a composite state with the option to
 : change cycle times and transition probabilities.
 : @param $mba investigated MBA
 : @param $level level of process
 : @param $inState only MBAs which are in this state are considered
 : @param $state state
 : @param $changedStates states, which cycle times are changed
 : @param $changedTransitions transitions, which probability is changed
 : @param $changedTransitionsFactors new probabilities of changed transitions
 : @return cycle time of composite state
 :)
declare function analysis:getCycleTimeForCompositeState(
        $mba as element(),
        $level as xs:string,
        $inState as xs:string?,
        $state as element(),
        $changedStates as element()?,
        $changedTransitions as element()*,
        $changedTransitionsFactors as xs:decimal*
) as xs:duration? {
    let $scxml := analysis:getSCXMLAtLevel($mba, $level)

    return
        if ($state/(descendant::sc:state | descendant::sc:parallel | descendant::sc:final)/@id = $changedStates/state/@id) then
            let $cycleTimes :=
                for $substate in $state/(sc:state | sc:parallel | sc:final)
                return
                    analysis:getCycleTimeForCompositeState($mba, $level, $inState, $substate, $changedStates, $changedTransitions, $changedTransitionsFactors)
            return
                if (analysis:isParallel($state)) then
                    max($cycleTimes)
                else
                    fn:sum($cycleTimes)
        else
            let $sccMap := analysis:tarjanAlgorithm($scxml)
            return
                analysis:getAverageCycleTime($mba, $level, $inState, $state/@id) *
                        analysis:getTransitionProbabilityForTargetState($scxml, $state, $changedTransitions, $changedTransitionsFactors, $sccMap) *
                        analysis:getChangedStateFactor($state, $changedStates)
};

(:~ 
 : This function returns the factor a state's cycle time has to be changed.
 : @param $state state
 : @param $changedStates factors for states
 : @return factor a state's cycle time has to be changed
 :)
declare function analysis:getChangedStateFactor(
        $state as element(),
        $changedStates as element()?
) as xs:double? {
    if ($state/@id = $changedStates/state/@id) then
    (: $state is changed: changedFactor :)
        number($changedStates/state[@id = $state/@id]/@factor)
    else if ($state/(ancestor::sc:state | ancestor::sc:parallel | ancestor::sc:final)/@id = $changedStates/state/@id) then
    (: parent is changed :)
        number($changedStates/state[@id = $state/(ancestor-or-self::sc:state | ancestor-or-self::sc:parallel | ancestor-or-self::sc:final)/@id]/@factor)
    else (: not changed :)
        1
};

(:~ 
 : This function returns the probability of a transition.
 : @param $transition transition
 : @param $changedTransitions transitions, which probability is changed
 : @param $changedTransitionsFactors new probabilities of changed transitions
 : @return probability of transition
 :)
declare function analysis:getProbabilityFactor(
        $transition as element(),
        $changedTransitions as element()*,
        $changedTransitionsFactors as xs:decimal*
) as xs:decimal {
    if (not(analysis:transitionInChangedTransitions($transition, $changedTransitions))) then
        analysis:getTransitionProbability($transition)
    else
        $changedTransitionsFactors[position() = functx:index-of-node($changedTransitions, $transition)]
};

(:~ 
 : This function returns all transitions that enter a given state.
 : @param $scxml process model
 : @param $state state
 : @return transitions that enter state
 :)
declare function analysis:getTransitionsToState(
        $scxml as element(),
        $state as element()
) as element()* {
    analysis:getTransitionsToState($scxml, $state, true(), true())
};

(: gets all transitions which result in entering $state :)
(: $includeSubstates: whether transitions with target=substateOf$state should be included or not. Needed for Calculation of @initial/<sc:initial> :)
(:~ 
 : This function returns all transitions that enter a given state.
 : @param $scxml process model
 : @param $state state
 : @param $includeSubstates true, if transitions to substates should be included
 : @param $checkParallel true, if transitions to a parallel state should be
 :        included
 : @return transitions that enter state
 :)
declare function analysis:getTransitionsToState(
        $scxml as element(),
        $state as element(),
        $includeSubstates as xs:boolean,
        $checkParallel as xs:boolean(: ## Workaround to avoid stackoverflow when initial is nested in child of parallel ## :)
) as element()* {
    if (analysis:stateIsInitialOfSCXML($state) = true()) then
        ()
    else if (analysis:stateIsInitial($state) = true()) then
    (: <sc:initial>: transitions to parenentrt ONLY, as there are no transitions to <sc:initial> :)
        analysis:getTransitionsToState($scxml, $state/.., false(), true())
    else if (
            analysis:parentIsParallel($state) and
                    $checkParallel = true()
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
                    if (not($includeSubstates)) then (: special treatment for substates of parallel :)
                        let $siblings := analysis:getSiblingStates($state)
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
            (
                if ($includeSubstates) then
                (: include transitions where target is $state or a substate of $state, but only if source of transition is not also a substate of $state :)
                    let $substates := analysis:getStateAndSubstates($scxml, $state/@id)
                    return $scxml//sc:transition[@target = $substates][not(functx:is-value-in-sequence(../@id, $substates))]
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

(:~ 
 : This function returns all siblings of a state.
 : @param $state state
 : @return all siblings
 :)
declare function analysis:getSiblingStates(
        $state as element()
) as element()* {
    ($state/(following-sibling::sc:state | following-sibling::sc:parallel | following-sibling::sc:initial | following-sibling::sc:final)) |
            $state/(preceding-sibling::sc:state | preceding-sibling::sc:parallel | preceding-sibling::sc:initial | preceding-sibling::sc:final)
};

(:~ 
 : This function returns the absolute probability of a state.
 : @param $scxml process model
 : @param $state state
 : @param $changedTransitions transitions, which probability is changed
 : @param $changedTransitionsFactors new probabilities of changed transitions
 : @param $scc strongly connected components of process model
 : @return probability of state
 :)
declare function analysis:getTransitionProbabilityForTargetState(
        $scxml as element(),
        $state as element(),
        $changedTransitions as element()*,
        $changedTransitionsFactors as xs:decimal*,
        $sccMap as map(*)
) as xs:decimal {
    if (analysis:stateIsInitialOfSCXML($state) = true()) then
        1
    else
        let $transitions := analysis:getTransitionsToState($scxml, $state)
        let $scc := analysis:getSCCForRootNode($state, $sccMap)
        return
            if (empty($scc)) then (: no loop :)
                fn:sum(
                        for $transition in $transitions
                        return
                            analysis:getProbabilityFactor($transition, $changedTransitions, $changedTransitionsFactors)
                                    * analysis:getTransitionProbabilityForTargetState($scxml, sc:getSourceState($transition), $changedTransitions, $changedTransitionsFactors, $sccMap)
                        ,
                        0
                )
            else
                analysis:getProbabilityForRootNode($scxml, $scc, $changedTransitions, $changedTransitionsFactors) (: probability for root node of strongly connected components :)
                        * fn:sum(
                        for $transition in $transitions
                        return
                            if (not(functx:is-node-in-sequence(sc:getSourceState($transition), $scc))) then (: only states which are not in scc :)
                                analysis:getProbabilityFactor($transition, $changedTransitions, $changedTransitionsFactors)
                                        * analysis:getTransitionProbabilityForTargetState($scxml, sc:getSourceState($transition), $changedTransitions, $changedTransitionsFactors, $sccMap)
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

(:~ 
 : This function returns a strongly connected component if state is it's root.
 : @param $scxml process model
 : @param $state state
 : @return strongly connected components
 :)
declare function analysis:getSCCForRootNodeTarjan(
        $scxml as element(),
        $state as element()
) as element()* {
    let $sccMap := analysis:tarjanAlgorithm($scxml)
    return analysis:getSCCForRootNode($state, $sccMap)
};

(:~ 
 : This function returns a strongly connected component if state is it's root.
 : @param $state state
 : @param $sccMap map of all strongly connected components
 : @return strongly connected components
 :)
declare function analysis:getSCCForRootNode(
        $state as element(),
        $sccMap as map(*)
) as element()* {
    fn:for-each(
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
};

(:~ 
 : This function returns the relative probability of the root node of a strongly
 : connected component.
 : @param $scxml process model
 : @param $scc strongly connected component
 : @param $changedTransitions transitions, which probability is changed
 : @param $changedTransitionsFactors new probabilities of changed transitions
 : @return probability of root node
 :)
declare function analysis:getProbabilityForRootNode(
        $scxml as element(),
        $scc as element()*,
        $changedTransitions as element()*,
        $changedTransitionsFactors as xs:decimal*
) as xs:decimal {
    let $r :=
        fn:sum(
                for $t in analysis:getTransitionsToState($scxml, analysis:getRootNodeOfSCC($scc))
                return
                    if (functx:is-node-in-sequence(sc:getSourceState($t), $scc)) then
                        analysis:getProbabilityFactor($t, $changedTransitions, $changedTransitionsFactors) *
                                analysis:getR($scxml, $scc, sc:getSourceState($t))
                    else
                        0
        )

    return 1 div (1 - $r)
};

(:~ 
 : This function returns the value of R (probability that loop is taken), used
 : for the calculation of the probability of a root node of a strongly connected
 : component.
 : @param $scxml process model
 : @param $scc strongly connected component
 : @param $state state
 : @return r
 :)
declare function analysis:getR(
        $scxml as element(),
        $scc as element()*,
        $state as element()
) as xs:decimal {
    if ($state is analysis:getRootNodeOfSCC($scc)) then
        1
    else
        fn:sum(
                for $t in analysis:getTransitionsToState($scxml, $state)
                return
                    if (functx:is-node-in-sequence(sc:getSourceState($t), $scc)) then
                        analysis:getTransitionProbability($t) *
                                analysis:getR($scxml, $scc, sc:getSourceState($t))
                    else
                        0
        )
};

(:~ 
 : This function returns the root node of a given strongly connected component.
 : @param $scc strongly connected component
 : @return root node of strongly connected component
 :)
declare function analysis:getRootNodeOfSCC(
        $scc as element()*
) as element() {
    $scc[last()]
};

(:~ 
 : This function checks if a transition is in the sequence of changed
 : transitions, based on node identity.
 : @param $transition transition
 : @param $changedTransitions changed transitions
 : @return true if transition is in changed transitions
 :)
declare function analysis:transitionInChangedTransitions(
        $transition as element(),
        $changedTransitions as element()*
) as xs:boolean {
    functx:is-node-in-sequence($transition, $changedTransitions)
};

(:~ 
 : This function returns the relative probability of a transition.
 : @param $transition transition
 : @return probability of transition
 :)
declare function analysis:getTransitionProbability(
    $transition as element()
) as xs:decimal {
    let $sourceState := sc:getSourceState($transition)

    (:
        for each descendant, check (via event log)
         - how often the source state of transition is left
         - how often the target state is entered via $transition
            - check for $source, $target, $event, $cond
    :)

    let $prob :=
        if (fn:compare(fn:name($sourceState), 'sc:initial') = 0) then
            <log leftState='true' tookTransition='true'/>
        else
            let $mba := $transition/ancestor::mba:mba[last()]
            let $level := $transition/ancestor::mba:elements[1]/../@name
            let $descendants :=
                analysis:getDescendantsAtLevelOrMBA($mba, $level)
            for $descendant in $descendants
            let $log := analysis:getEventLog(mba:getSCXML($descendant))
            return
                for $event in $log/xes:trace/xes:event
                let $transitionEvent := analysis:getTransitionForLogEntry(mba:getSCXML($descendant), $event)
                return
                    <log leftState='{analysis:stateIsLeft($transitionEvent, $sourceState/@id)}' tookTransition='{analysis:compareTransitions($transition, $transitionEvent)}'/>

    return
        if (fn:count($prob[@leftState = 'true']) > 0) then
            fn:count($prob[@tookTransition = 'true' and @leftState = 'true']) div fn:count($prob[@leftState = 'true'])
        else
            0
};

(:~ 
 : This function checks if a state is left by a transition.
 : State is left if:
 : 1. $transition/source = $state AND $transition/target is neither $state nor a
 :    substate
 : 2. $transition/source is a substate of $state AND $transition/target is
 :    neither $state nor a substate
 : @param $state state
 : @param $transition transition
 : @return true if state is left by transition
 :)
declare function analysis:stateIsLeft(
        $transition as element(),
        $state as xs:string
) as xs:boolean {
    if (analysis:stateIsInitial(sc:getSourceState($transition))) then
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
};

(:~ 
 : This function checks if one transition is a specialization of another
 : transition.
 : Rules:
 : 1. $newTransition may have a more specialized source state.
 : 2. $newTransition may have a more specialized target state.
 :   - If both have no target, then target check is ok
 :   - if source has no target, newTransition may have a target which is
 :     stateOrSubstate of source
 : 3. condition may be added to $newTransition (if $origTransition had no cond).
 :    If no condition, every cond can be introduced
 : 4. conditions in $newTransition may be specialized, by adding terms with 'AND'
 : 5. dot notation of events. If no event, every event can be introduced
 : @param $origTransition original transition
 : @param $newTransition spezialized transition
 : @return true if second transition is a valid spezialization of the other
 :)
declare function analysis:compareTransitions(
        $origTransition as element(),
        $newTransition as element()
) as xs:boolean {
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

(:~ 
 : This function returns the average cycle time of a state.
 : @param $mba investigated MBA
 : @param $level level of process
 : @param $inState only MBAs which are in this state are considered
 : @param $stateId id of state
 : @return average cycle time of state
 :)
declare function analysis:getAverageCycleTime(
        $mba as element(),
        $level as xs:string,
        $inState as xs:string?,
        $stateId as xs:string
) as xs:duration? {
    let $descendants :=
        analysis:getDescendantsAtLevelOrMBA($mba, $level)
        [if ($inState) then mba:isInState(., $inState) else true()]

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

(:~ 
 : This function returns the time a MBA stays in given states. States must not
 : be substates of each other.
 : @param $mba investigated MBA
 : @param $states states
 : @return time MBA stays in states
 :)
declare function analysis:getTotalCycleTimeInStates(
        $mba as element(),
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

(:~ 
 : This function returns the state log of a MBA
 : @param $mba investigated MBA
 : @return state log
 :)
declare function analysis:getStateLog(
        $mba as element()
) as element() {
    let $scxml := mba:getSCXML($mba)
    let $log := analysis:getEventLog($scxml)

    (: get all events :)
    let $events := for $event in $log/xes:trace/xes:event
    order by $event/xes:date[@key = 'time:timestamp']/@value
    return $event

    let $stateLog := fn:fold-left($events,
            map:merge((
                map:entry('configuration', ()),
                map:entry('stateLog', ())
            )),
            function($result, $event) {
            (: get configuration and result entries from result-map :)
                let $configuration := map:get($result, 'configuration')
                let $stateLog := map:get($result, 'stateLog')

                let $eventTimestamp :=
                    xs:dateTime($event/xes:date[@key = 'time:timestamp']/@value)

                let $transition := analysis:getTransitionForLogEntry($scxml, $event)

                let $entrySet := sc:computeEntrySet($transition)
                let $exitSet := sc:computeExitSet($configuration, $transition)

                let $newStateLogEntries := for $state in $entrySet return
                    <state ref="{$state/@id}" from="{$eventTimestamp}"/>

                let $stateLog := for $entry in $stateLog return
                    if (not($entry/@until) and (some $state in $exitSet satisfies $state/@id = $entry/@ref)) then
                        copy $new := $entry modify (
                            insert node attribute until {$eventTimestamp} into $new
                        ) return $new
                    else $entry

                let $newConfiguration := (
                  $configuration[not(some $state in $exitSet satisfies $state is .)],
                  $entrySet
                )

                return map:merge((
                    map:entry('configuration', $newConfiguration),
                    map:entry('stateLog', ($stateLog, $newStateLogEntries))
                ))
            }
    )

    return <stateLog>{map:get($stateLog, 'stateLog')}</stateLog>
};

(:~ 
 : This function returns the event log of a scxml model.
 : @param $scxml process model
 : @return event log
 :)
declare function analysis:getEventLog(
        $scxml as element()
) as element() {
    $scxml/sc:datamodel/sc:data[@id = "_x"]/xes:log
};

(:~ 
 : This function returns a state including his substates.
 : @param $scxml process model
 : @param $state state
 : @return states and substates
 :)
declare function analysis:getStateAndSubstates(
        $scxml as element(),
        $state as xs:string
) as xs:string* {
    $scxml//(sc:state | sc:parallel | sc:final)[@id = $state]/(descendant-or-self::sc:state | descendant-or-self::sc:parallel | descendant-or-self::sc:final)/fn:string(@id)
};

(:~ 
 : This function returns all parent states of a state.
 : @param $scxml process model
 : @param $state state
 : @return parent states
 :)
declare function analysis:getParentStates(
        $scxml as element(),
        $state as xs:string
) as xs:string* {
    $scxml//(sc:state | sc:parallel | sc:final)[@id = $state]/(ancestor::sc:state | ancestor::sc:parallel | ancestor::sc:final)/fn:string(@id)
};

(:~ 
 : This function checks if a condition is a spezialization of another.
 : @param $origCond original condition
 : @param $newCond spezialized condition
 : @return true, if second condition is a valid spezialization of the first
 :)
declare function analysis:compareConditions(
        $origCond as xs:string,
        $newCond as xs:string
) as xs:boolean {
    (fn:compare($origCond, $newCond) = 0) or
            ((fn:compare($origCond, fn:substring($newCond, 1, fn:string-length($origCond))) = 0) and
                    (fn:compare(' and ', fn:substring($newCond, fn:string-length($origCond) + 1, 5)) = 0))
};

(:~ 
 : This function checks if an event is a spezialization of another.
 : @param $origEvent original event
 : @param $newEvent spezialized event
 : @return true, if second event is a valid spezialization of the first
 :)
declare function analysis:compareEvents(
        $origEvent as xs:string,
        $newEvent as xs:string
) as xs:boolean {
    (fn:compare($origEvent, $newEvent) = 0) or
            ((fn:compare($origEvent, fn:substring($newEvent, 1, fn:string-length($origEvent))) = 0) and
                    (fn:compare('.', fn:substring($newEvent, fn:string-length($origEvent) + 1, 1)) = 0))
};

(:~ 
 : This function returns the transition which corresponds to a log entry.
 : @param $scxml process model
 : @param $event event log entry
 : @return transition
 :)
declare function analysis:getTransitionForLogEntry(
        $scxml as element(),
        $event as element()
) as element() {
    let $eventState := fn:string($event/xes:string[@key = 'sc:state']/@value)
    let $eventInitial := fn:string($event/xes:string[@key = 'sc:initial']/@value)
    let $eventEvent := fn:string($event/xes:string[@key = 'sc:event']/@value)
    let $eventTarget := fn:string($event/xes:string[@key = 'sc:target']/@value)
    let $eventCond := fn:string($event/xes:string[@key = 'sc:cond']/@value)

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

(:~ 
 : This function returns the cycle time of a state log entry.
 : @param $stateLogEntry state log entry
 : @return cycle time of state log entry
 :)
declare function analysis:getCycleTimeOfStateLogEntry(
        $stateLogEntry as element()
) as xs:duration {
    if ($stateLogEntry/@until) then
        xs:dateTime($stateLogEntry/@until) -
                xs:dateTime($stateLogEntry/@from)
    else fn:current-dateTime() -
            xs:dateTime($stateLogEntry/@from)
};

(:~ 
 : This function returns a state log until a given state is reached.
 : @param $mba investigated MBA
 : @param $toState state log is generated until this state is reached
 : @return state log until state
 :)
declare function analysis:getStateLogToState(
        $mba as element(),
        $toState as xs:string?
) as element() {
    let $stateLog := analysis:getStateLog($mba)
    return
        if ($toState) then
            element {fn:node-name($stateLog)} {$stateLog/state[@ref = $toState]/(self::state | preceding-sibling::state)}
        else
            $stateLog
};

(:~ 
 : This function returns the process model of a level of a MBA.
 : @param $mba investigated MBA
 : @param $level level of process
 : @return process model
 :)
declare function analysis:getSCXMLAtLevel(
        $mba as element(),
        $level as xs:string
) as element()* {
    ($mba/mba:topLevel[@name = $level])/mba:elements/sc:scxml |
            ($mba//mba:childLevel[@name = $level])[1]/mba:elements/sc:scxml
};

(:~ 
 : This function returns all descendants of a MBA which are or have been in a
 : given state.
 : @param $mba investigated MBA
 : @param $level level of process
 : @param $toState state
 : @return descendants which are or have been in state
 :)
declare function analysis:getDescendantsAtLevel(
        $mba as element(),
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

(:~ 
 : This function returns all states of a process model with the option to
 : exclude archive states.
 : @param $scxml process model
 : @param $excludeArchiveStates option to exclude archive states
 : @return states of process model
 :)
declare function analysis:getStates(
        $scxml as element(),
        $excludeArchiveStates as xs:boolean?
) as element()* {
    if ($excludeArchiveStates = true()) then
        $scxml//(sc:state | sc:parallel | sc:final)[not(@mba:isArchiveState = $excludeArchiveStates)]
    else
        $scxml//(sc:state | sc:parallel | sc:final)
};

(:~ 
 : This function returns the most abstract states of a process model with the option to
 : exclude archive states.
 : @param $scxml process model
 : @param $excludeArchiveStates option to exclude archive states
 : @return most abstract states of process model
 :)
declare function analysis:getMostAbstractStates(
        $scxml as element(),
        $excludeArchiveStates as xs:boolean?
) as element()* {
    if ($excludeArchiveStates = true()) then
        $scxml/(sc:state | sc:parallel | sc:final)[not(@mba:isArchiveState = $excludeArchiveStates)]
    else
        $scxml/(sc:state | sc:parallel | sc:final)
};

(:~ 
 : This function returns all descendants of a given level or, if the given level
 : is the top level, the MBA itself.
 : @param $mba investigated MBA
 : @param $level level of process
 : @param $toState option to only include descendants that are or have been in
 :        this state
 : @return descendants or MBA
 :)
declare function analysis:getDescendantsAtLevelOrMBA(
        $mba as element(),
        $level as xs:string,
        $toState as xs:string?
) as element()* {
    if ($mba/mba:topLevel[@name = $level]) then
        $mba
    else
        analysis:getDescendantsAtLevel($mba, $level, $toState)
};

(:~ 
 : This function returns all descendants of a given level or, if the given level
 : is the top level, the MBA itself.
 : @param $mba investigated MBA
 : @param $level level of process
 : @return descendants or MBA
 :)
declare function analysis:getDescendantsAtLevelOrMBA(
        $mba as element(),
        $level as xs:string
) as element()* {
    analysis:getDescendantsAtLevelOrMBA($mba, $level, ())
};

(:~ 
 : This function returns the function of a transition's condition.
 : @param $cond condition
 : @return function
 :)
declare function analysis:parseFunction(
        $cond as xs:string
) as xs:string {
    fn:substring-before($cond, "(")
};

(:~ 
 : This function removes the first and last character of the given string if
 : both are "'".
 : @param $param param
 : @return truncated param
 :)
declare function analysis:truncateParam(
        $param as xs:string
) as xs:string {
    let $param := functx:trim($param)
    return
        if ((substring($param, 1, 1) = "'") and (substring($param, string-length($param), 1) = "'")) then
            substring(substring($param, 0, string-length($param)), 2)
        else
            $param
};

(:~ 
 : This function parses the first param of the sync. predicate in a transition's
 : condition. This is the string between opening bracket and first comma, so it
 : must not contains commas.
 : @param $cond condition
 : @return first param, i.e. level name
 :)
declare function analysis:parseLevelTwoParams(
        $cond as xs:string
) as xs:string {
    analysis:truncateParam(fn:substring-before(fn:substring-after($cond, "("), ","))
};

(:~ 
 : This function parses the second param of the sync. predicate in a transition's
 : condition. This is the string between first comma and next ")".
 : @param $cond condition
 : @return second param, i.e. state id
 :)
declare function analysis:parseStateTwoParams(
        $cond as xs:string
) as xs:string {
    analysis:truncateParam(fn:substring-before(fn:substring-after($cond, ","), ")"))
};

(:~ 
 : This function parses the first param of the sync. predicate in a transition's
 : condition.
 : @param $cond condition
 : @return first param, i.e. object
 :)
declare function analysis:parseObjectThreeParams(
        $cond as xs:string
) as xs:string {
    analysis:truncateParam(substring-after(functx:substring-before-last(functx:substring-before-last($cond, ","), ","), concat(analysis:parseFunction($cond), "(")))
};

(:~ 
 : This function parses the second param of the sync. predicate in a transition's
 : condition. Must not contains commas.
 : @param $cond condition
 : @return second param, i.e. level name
 :)
declare function analysis:parseLevelThreeParams(
        $cond as xs:string
) as xs:string {
    analysis:truncateParam(functx:substring-after-last(functx:substring-before-last($cond, ","), ","))
};

(:~ 
 : This function parses the third param of the sync. predicate in a transition's
 : condition. Must not contains commas.
 : @param $cond condition
 : @return third param, i.e. state id
 :)
declare function analysis:parseStateThreeParams(
        $cond as xs:string
) as xs:string {
    analysis:truncateParam(functx:substring-after-last(functx:substring-before-last($cond, ")"), ","))
};

(:~ 
 : This function returns the creation time of a MBA.
 : @param $mba investigated MBA
 : @return creation time
 :)
declare function analysis:getCreationTime(
        $mba as element()
) as xs:dateTime {
    xs:dateTime(analysis:getStateLog($mba)/state/@from[1])
};

(:~ 
 : This function returns a map of all strongly connected components of a process
 : model.
 : @param $scxml process model
 : @return strongly connected components
 :)
declare function analysis:tarjanAlgorithm(
        $scxml as element()
) as map(*) {
    let $scc :=
        map:get(
                fn:fold-left($scxml//(sc:state | sc:parallel | sc:final),
                        analysis:createMap(0, (), (), (), ()),
                        function($result, $state) {
                            let $indexes := map:merge(map:get($result, 'indexes'))
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

(:~ 
 : This function provides the functionality of the tarjan algorithm.
 : @param $scxml process model
 : @param $state state
 : @param $resultMap map for environment variables
 : @return strongly connected components
 :)
declare function analysis:strongconnect(
        $scxml as element(),
        $state as element(),
        $resultMap as map(*)
) as map(*) {
    let $index := map:get($resultMap, 'index') (: next index :)
    let $indexes := map:merge((map:get($resultMap, 'indexes'), map:entry($state/@id, $index)))
    let $lowlink := $index
    let $lowlinks := map:merge((map:get($resultMap, 'lowlinks'), map:entry($state/@id, $lowlink)))

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
                                    map:merge(($lowlinks, map:entry($state/@id, $lowlink))),
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
                                    map:merge(($lowlinks, map:entry($state/@id, $lowlink))),
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

(:~ 
 : This function creates a map of environment variables used by the tarjan
 : algorithm.
 : @param $index global index
 : @param $indexes mapping of state to index
 : @param $lowlinks mapping of state to lowlinks
 : @param $stack sequence which simulates stack
 : @param $scc strongly connected components
 : @return map with environment variables
 :)
declare function analysis:createMap(
        $index as xs:integer,
        $indexes as map(*)?,
        $lowlinks as map(*)?,
        $stack as element()*,
        $scc as map(*)?
) as map(*) {
    map:merge((
        map:entry('index', $index),
        map:entry('indexes', $indexes),
        map:entry('lowlinks', $lowlinks),
        map:entry('stack', $stack),
        map:entry('scc', $scc)
    ))
};

(:~ 
 : This function checks if a state was already visited by the tarjan algorithm.
 : @param $indexes mapping of state to index
 : @param $state state
 : @return true if state was not already visited
 :)
declare function analysis:notVisited(
        $indexes as map(*),
        $state as xs:string
) as xs:boolean {
    fn:empty(map:get($indexes, $state))
};

(:~ 
 : This function checks if a state is currently placed on the stack.
 : @param $stack sequence which simulates stack
 : @param $state state
 : @return true if state is on stack
 :)
declare function analysis:onStack(
        $stack as element()*,
        $state as element()
) as xs:boolean {
    functx:is-node-in-sequence($state, $stack)
};

(:~ 
 : This function pops states from the stack until the popped state equals the
 : given state. The popped states are added to a new strongly connected
 : component which is returned.
 : @param $stack sequence which simulates stack
 : @param $scc strongly connected component
 : @param $state state
 : @return new stack and scc
 :)
declare function analysis:popStack(
        $stack as element()*,
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

(:~ 
 : This function returns all successors of a state.
 : @param $scxml process model
 : @param $state state
 : @return successors of state
 :)
declare function analysis:getSuccessors(
        $scxml as element(),
        $state as xs:string
) as element()* {
    $scxml//(sc:state | sc:parallel | sc:final)[@id = analysis:getTransitionsLeavingState($scxml, $state)/@target]
};

(:~ 
 : This function returns all transitions which leave a state.
 : @param $scxml process model
 : @param $state state
 : @return transitions leaving state
 :)
declare function analysis:getTransitionsLeavingState(
        $scxml as element(),
        $state as xs:string
) as element()* {
    $scxml//(sc:state | sc:parallel | sc:final)[@id = $state]//sc:transition[analysis:stateIsLeft(., $state)]
};

(:~ 
 : This function returns a state element for a state id.
 : @param $scxml process model
 : @param $state state id
 : @return state element
 :)
declare function analysis:getState(
        $scxml as element(),
        $state as xs:string
) as element()* {
    $scxml//(sc:state | sc:parallel | sc:final)[@id = $state]
};