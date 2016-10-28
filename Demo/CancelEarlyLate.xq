(:
 : This file contains tests for calculating probabilities of spezialised transitions
 :)

xquery version "3.0";

declare namespace xes='http://www.xes-standard.org/';

import module namespace mba  = 'http://www.dke.jku.at/MBA';
import module namespace functx = 'http://www.functx.com';
import module namespace analysis='http://www.dke.jku.at/MBA/Analysis';
import module namespace sc='http://www.w3.org/2005/07/scxml';

let $testData := db:open("CancelEarlyLate")
let $mba := $testData/mba:mba
let $mbaPrivate1 := $testData//mba:mba[@name="Private1"]
let $tBusiness := $mba/mba:topLevel/mba:childLevel/mba:childLevel/mba:elements//sc:transition[@event="cancel"]
let $tPrivate := $mbaPrivate1//mba:childLevel//sc:transition[@event="cancel.late"]

let $stateId := "Closed"
let $scxmlPrivate1 := $mbaPrivate1/mba:topLevel/mba:childLevel[@name="rental"]/mba:elements/sc:scxml
let $state := $scxmlPrivate1//sc:state[@id=$stateId]
let $transitions := analysis:getTransitionsToState($scxmlPrivate1, $state, true(), true())

return
    (
        concat('Prob. of state ', $stateId, ': ', analysis:getTransitionProbabilityForTargetState($scxmlPrivate1, $state, (), (), map:merge(())))
        ,
        concat('Prob. of transition cancel (mba: Business): ', analysis:getTransitionProbability($tBusiness))
        ,
        concat('Prob. of transition cancel.late (mba: Private): ', analysis:getTransitionProbability($tPrivate))
        ,
        for $x in $transitions
        return
            element { "t" } {
                attribute prob {analysis:getTransitionProbability($x)},
                $x/../@id,
                $x/@event
            }
    )