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
    let $descendants := mba:getDescendantsAtLevel($mba, $level)

    let $cycleTimes :=
        for $descendant in $descendants
        return analysis:getCycleTimeOfInstance($descendant, $toState)

    return fn:avg($cycleTimes)
};

declare function analysis:getTotalCycleTime($mba as element(),
    $level as xs:string,
    $toState as xs:string?,
    $changedStates as element()*
) (:as xs:duration:){ (: no stateLog needed!, write function new :)
    let $descendants := mba:getDescendantsAtLevel($mba, $level)

    let $sum := for $descendant in $descendants
        let $stateLog := analysis:getStateLogToState($descendant, $toState)/state
        let $scxml := mba:getSCXML($descendant)
        for $entry in $stateLog
        return
            if (functx:is-value-in-sequence($entry/@ref, $scxml/*[self::sc:state|self::sc:parallel|self::sc:initial]/@id)) then
            (: 'first level' states :)
                if (functx:is-value-in-sequence($entry/@ref, $changedStates/state/@id)) then
                (: current state is changed, ToDo: return time for stateLogEntry * factor * transitionProbability :)
                    element{'state'}{$entry/@ref, $changedStates/state[@id=$entry/@ref]/@factor}
                else if ($scxml/*[@id=$entry/@ref]/(descendant::sc:state|descendant::sc:parallel|descendant::sc:initial)/@id = $changedStates/state/@id) then
                (: id of at least one descendant of $entry/@ref in $changedStates/state/@id :)
                    for $substate in $scxml/*[@id=$entry/@ref]/(sc:state|sc:parallel|sc:initial)
                        return analysis:getTotalCycleTimeRecursive($descendant, $substate/@id, $toState, $changedStates)
                else
                    (: neither current nor descendant states are changed. ToDo: return time for stateLogEntry * transitionProbability:)
                    element{'state'}{$entry/@ref, attribute factor {'1'}}
            else
                () (: no 'first level' state :)
    return $sum
};

declare %private function analysis:getTotalCycleTimeRecursive($mba as element(),
    $stateId as xs:string,
    $toState as xs:string?,
    $changedStates as element()
) {
    let $entry := analysis:getStateLogToState($mba, $toState)/state[@ref=$stateId] (: ToDo: how to get the correct stateLog entry?? :)
    let $state := mba:getSCXML($mba)//(sc:state|sc:parallel|sc:initial)[@id=$stateId]

    return
        if ($entry) then
            if (functx:is-value-in-sequence($stateId, $changedStates/state/@id)) then
            (: current state is changed, ToDo: return time for stateLogEntry * factor * transitionProbability :)
                element{'state'}{attribute ref {$stateId}, $changedStates/state[@id=$stateId]/@factor}
            else if ($state/(descendant::sc:state|descendant::sc:parallel|descendant::sc:initial)/@id = $changedStates/state/@id) then
            (: id of at least one descendant of $entry/@ref in $changedStates/state/@id :)
                for $substate in $state/(sc:state|sc:parallel|sc:initial)
                    return analysis:getTotalCycleTimeRecursive($mba, $substate/@id, $toState, $changedStates)
            else
            (: neither current nor descendant states are changed. ToDo: return time for stateLogEntry * transitionProbability :)
                element{'state'}{attribute ref {$stateId}, attribute factor {'1'}}
        else
            () (: state not in $stateLog :)
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

(: returns average cycle time of a state :)
declare function analysis:getAverageCycleTime($mba as element(),
        $level as xs:string,
        $inState as xs:string,
        $stateId as xs:string
) as xs:duration {
    let $descendants :=
        mba:getDescendantsAtLevel($mba, $level)
        [mba:isInState(., $inState)]

    let $cycleTimes :=
        for $descendant in $descendants
        let $stateLog := analysis:getStateLog($descendant)
        return fn:sum(
                (
                    for $entry in $stateLog/state[@ref = $stateId] return
                        analysis:getCycleTimeOfStateLogEntry($entry)
                ),
                ()
        )

    return fn:avg($cycleTimes)
};

(: returns total cycle time an instance was in given states :)
declare function analysis:getTotalCycleTimeInStates($mba as element(),
        $level as xs:string,
        $states as xs:string*
) as xs:duration {
    let $stateLog := analysis:getStateLog($mba)

    (: ToDo: include $level and check if $states are substates of each other :)
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

declare function analysis:getTransitionProbability($transition as element()
) as xs:decimal {
    let $mba := $transition/ancestor::mba:mba[last()]
    let $level := $transition/ancestor::mba:topLevel[1]/@name
    let $descendants := mba:getDescendantsAtLevel($mba, $level)

    let $source := sc:getSourceState($transition)/@id
    let $target := $transition/@target
    let $cond := $transition/@cond
    let $event := $transition/@event

    (:
        for each descendent, check (via event log)
         - how often the source state of transition is left
         - how often the target state is entered via $transition
            - check for $source, $target, $event, $cond
    :)
    let $prob :=
        for $descendant in $descendants
            let $log := mba:getSCXML($descendant)/sc:datamodel/sc:data[@id = "_x"]/xes:log
            return
                for $event in $log/xes:trace/xes:event
                    let $transitionEvent := analysis:getTransitionsForLogEntry(mba:getSCXML($descendant), $event)

                    return (: left-state is true if state was left, took-transition is true if transition was taken :)
                        <log leftState='{analysis:stateIsLeft($transitionEvent, $source)}' tookTransition='{analysis:compareTransitions($transition, $transitionEvent)}'/>
    return fn:count($prob[@tookTransition='true']) div fn:count($prob[@leftState='true'])
};

declare function analysis:stateIsLeft($transition as element(),
        $state as xs:string
) (:as xs:boolean:) {
(:
    true if:
        1. $transition/source = $state AND $transition/target is neither $state nor a substate
        2. $transition/source is a substate of $state AND $transition/target is neither $state nor a substate
    else false
:)
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
(: ToDo: what if $state is a substate of $transition/source ? split occurences to substates? :)
};

declare function analysis:compareTransitions($origTransition as element(),
    $newTransition as element()
) as xs:boolean {
(:
    check if $origTransition is the 'same' as $newTransition
    rules:
        1. $newTransition may have a more specialized source state
        2. $newTransition may have a more specialized target state
        3. condition may be added to $newTransition (if $origTransition had no cond)
        4. conditions in $newTransition may be specialized, by adding terms with 'AND'
        5. dot notation of events
:)
    let $origSource := fn:string(sc:getSourceState($origTransition)/@id)
    let $origTarget := fn:string($origTransition/@target)

    let $scxml := $origTransition/ancestor::sc:scxml[1]
    let $origSourceAndSubstates := analysis:getStateAndSubstates($scxml, $origSource)
    let $origTargetAndSubstates := analysis:getStateAndSubstates($scxml, $origTarget)

    return
        if (
            (: 1. :)(functx:is-value-in-sequence(fn:string(sc:getSourceState($newTransition)/@id), $origSourceAndSubstates)) and
            (: 2. :)(functx:is-value-in-sequence(fn:string($newTransition/@target), $origTargetAndSubstates)) and
            (: 3&4:)(not($origTransition/@cond) or analysis:compareConditions($origTransition/@cond, $newTransition/@cond))
        (: ToDo: dot notation :)
        ) then
            true()
        else
            false()
};

declare function analysis:getStateAndSubstates($scxml as element(),
    $state as xs:string
) as xs:string* {
    $scxml//(sc:state|sc:parallel|sc:initial)[@id=$state]/(descendant-or-self::sc:state|descendant-or-self::sc:parallel|descendant-or-self::sc:initial)/fn:string(@id)
};

declare function analysis:compareConditions($origCond as xs:string,
    $newCond as xs:string
) {
    (fn:compare($origCond, $newCond)=0) or
    ((fn:compare($origCond, fn:substring($newCond, 1, fn:string-length($origCond)))=0) and
    (fn:compare(' and ', fn:substring($newCond, fn:string-length($origCond)+1, 5))=0))
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
            element{fn:node-name($stateLog)}{$stateLog/state[@ref = $toState]/preceding-sibling::state}
        else
            $stateLog
};

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