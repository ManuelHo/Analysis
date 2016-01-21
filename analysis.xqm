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
    $newStates as element()*
) (:as xs:duration:){
    (: prinzipiell obersten 'level' bei states nehmen :)
    (: außer ein substate davon ist in $newStates :)
    (: dann: anstatt dem obersten 'level' die siblings vom geänderten substate nehmen :)

    let $descendants := mba:getDescendantsAtLevel($mba, $level)

    let $sum := for $descendant in $descendants
        let $stateLog := analysis:getStateLogToState($descendant, $toState)/state
        return for $state in mba:getSCXML($descendant)

        return 1
    return 1
};

(: returns cycle time of top level from MBA :)
(: by adding up cycle times of each states until $toState :)
(: WRONG FOR COMPOSITE STATES, HAS TO BE DELETED :)
declare function analysis:getCycleTimeOfInstanceBySum($mba as element(),
        $toState as xs:string?
) (:as xs:duration:) {
(: take states from stateLog until $toState, which is not included :)
    let $stateLog := analysis:getStateLogToState($mba, $toState)/state
    (:let $stateLog :=
        if ($toState) then
            analysis:getStateLog($mba)/state[@ref = $toState]/preceding-sibling::state
        else
            analysis:getStateLog($mba)/state:)

    (:let $cycleTimeOfInstance := fn:sum(
            (for $entry in $stateLog return
                analysis:getCycleTimeOfStateLogEntry($entry)), ()
    ):)

    (:return $cycleTimeOfInstance:)
    return $stateLog
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
declare function analysis:averageCycleTime($mba as element(),
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

declare function analysis:getTransitionProbability($mba as element(),
        $level as xs:string,
        $source as xs:string?, (: $source should not be optional.. :)
        $target as xs:string,
        $event as xs:string?
) (:as xs:decimal:) {
    let $descendants := mba:getDescendantsAtLevel($mba, $level)

    let $transitions := for $descendant in $descendants
        let $scxml := mba:getSCXML($descendant)
        let $log := $scxml/sc:datamodel/sc:data[@id = "_x"]/xes:log
        let $events := $log//xes:event

        return
            for $event in $events
            let $transition := analysis:getTransitionsForLogEntry($scxml, $event)

            let $entrySet := sc:computeEntrySet($transition)
            let $configuration := sc:getSourceState($transition)/ancestor-or-self::sc:state |
                    sc:getSourceState($transition)/ancestor-or-self::sc:parallel
            let $exitSet := sc:computeExitSet($configuration, $transition)

            return
                if (fn:exists($exitSet[@id=$source])) then
                    <log exit='{$exitSet[@id=$source]/@id}' enter='{$entrySet[@id=$target]/@id}'/>
                else ()

    return
        <result event='{$event}' source='{$source}' target='{$target}'>
            <left-source>{fn:count($transitions[@exit=$source])}</left-source>
            <entered-target>{fn:count($transitions[@enter=$target])}</entered-target>
            <probability>{fn:count($transitions[@enter=$target]) div fn:count($transitions[@exit=$source])}</probability>
        </result>
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


(: from probability

    (: find transition which fits to params; from state chart :)
    let $transition :=
        $scxml//sc:transition[
        (not($target or @target) or sc:computeEntrySet(.)/@id = $target) and
                (not($source) or ../ancestor-or-self::sc:state/@id = $source
                        or ../ancestor-or-self::sc:parallel/@id = $source) and
                (not($event or @event) or @event = $event) and
                (not($eventCond or @cond) or @cond = $eventCond) and
                (not($eventInitial) or (../../@id = $eventInitial or ../../@name = $eventInitial))
        ]
:)