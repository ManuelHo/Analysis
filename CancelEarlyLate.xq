xquery version "3.0";

declare namespace xes='http://www.xes-standard.org/';

import module namespace mba  = 'http://www.dke.jku.at/MBA' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/mba.xqm';
import module namespace functx = 'http://www.functx.com' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/functx.xqm';
import module namespace analysis='http://www.dke.jku.at/MBA/Analysis' at 'C:/Users/manue/Masterarbeit/Analysis/analysis.xqm';

import module namespace sc='http://www.w3.org/2005/07/scxml' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/scxml.xqm';


let $testData := fn:doc("C:/Users/manue/Masterarbeit/Analysis/Data/CancelEarlyLate.xml")

let $mba := $testData/mba:mba
let $mbaPrivate1 := $testData//mba:mba[@name="Private1"]

let $t := $mba/mba:topLevel/mba:childLevel/mba:childLevel/mba:elements//sc:transition[@event="assignCar"]

let $t1 := $mbaPrivate1//mba:childLevel//sc:transition[@event="cancel.late"]

let $stateId := "Open"
let $scxml := $mbaPrivate1/mba:topLevel/mba:childLevel[@name="rental"]/mba:elements/sc:scxml
let $scxml1 := $mba/mba:topLevel/mba:childLevel/mba:childLevel[@name="rental"]/mba:elements/sc:scxml

let $state := $scxml//sc:state[@id=$stateId]

let $transitions := analysis:getTransitionsToState($scxml, $state, true(), true())

return
    (
        analysis:getTransitionProbabilityForTargetState($scxml, $state, (), true(), true())
        ,
        analysis:getTransitionProbability($t1,())
        ,
        for $x in $transitions
            return
                element { "t" } {
                    attribute prob {analysis:getTransitionProbability($x, ())},
                    $x/../@id,
                    $x/@event
                }
    )

    (:



    :)