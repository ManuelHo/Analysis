xquery version "3.0";

declare namespace xes='http://www.xes-standard.org/';

import module namespace mba  = 'http://www.dke.jku.at/MBA' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/mba.xqm';
import module namespace functx = 'http://www.functx.com' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/functx.xqm';
import module namespace analysis='http://www.dke.jku.at/MBA/Analysis' at 'C:/Users/manue/Masterarbeit/Analysis/analysis.xqm';

import module namespace sc='http://www.w3.org/2005/07/scxml' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/scxml.xqm';


let $testData := fn:doc("C:/Users/manue/Masterarbeit/Analysis/Data/CancelEarlyLate.xml")

let $mba := $testData/mba:mba
let $mbaPrivate1 := $testData//mba:mba[@name="Private1"]

let $tBusiness := $mba/mba:topLevel/mba:childLevel/mba:childLevel/mba:elements//sc:transition[@event="assignCar"]

let $tPrivate := $mbaPrivate1//mba:childLevel//sc:transition[@event="assignCar"]

let $stateId := "Settled"
let $scxmlBusiness := $mbaPrivate1/mba:topLevel/mba:childLevel[@name="rental"]/mba:elements/sc:scxml
let $scxmlPrivate := $mba/mba:topLevel/mba:childLevel/mba:childLevel[@name="rental"]/mba:elements/sc:scxml

let $state := $scxmlBusiness//sc:state[@id=$stateId]

let $transitions := analysis:getTransitionsToState($scxmlBusiness, $state, true(), true())

let $distinct :=
    fn:fold-left(analysis:getTransitionsToState($scxmlBusiness,$state, true(), true()),
        (),
    function($result, $trans){
        let $a := ($result, $trans)
        return $a
    }
)

return (:analysis:getCycleTimeForCompositeState($mbaPrivate1, 'rental', 'Archived', $state, (), ()):)
analysis:getTotalCycleTimeToState($mbaPrivate1, 'rental', 'Archived', 'Archived', (), (), ())



(:return
    (
        concat('Prob. of state ', $stateId, ': ', analysis:getTransitionProbabilityForTargetState($scxmlBusiness, $state, (), true(), true()))
        ,
        concat('Prob. of transition (mba: Business): ', analysis:getTransitionProbability($tBusiness,()))
        ,
        concat('Prob. of transition (mba: Private): ', analysis:getTransitionProbability($tPrivate,()))
        ,
        for $x in $transitions
        return
            element { "t" } {
                attribute prob {analysis:getTransitionProbability($x, ())},
                $x/../@id,
                $x/@event
            }
    ):)