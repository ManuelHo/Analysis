xquery version "3.0";

declare namespace xes='http://www.xes-standard.org/';

import module namespace mba  = 'http://www.dke.jku.at/MBA' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/mba.xqm';
import module namespace functx = 'http://www.functx.com' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/functx.xqm';
import module namespace analysis='http://www.dke.jku.at/MBA/Analysis' at 'C:/Users/manue/Masterarbeit/Analysis/analysis.xqm';

import module namespace sc='http://www.w3.org/2005/07/scxml' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/scxml.xqm';

let $testData := fn:doc("C:/Users/manue/Masterarbeit/Analysis/Data/TestData.xml")

let $mba := $testData/mba:mba
let $mbaTactCar := $testData//mba:mba[@name="MyCarInsuranceCompany"]
let $mbaTactHouse := $testData//mba:mba[@name="MyHouseholdInsuranceCompany"]

let $mbaOptCarClerk := $testData//mba:mba[@name="MyCarInsuranceClerk"]

(: checks if the creation time of a mba is between 5:30 and 8:00 :)
(:let $timeFunc := function($mba as element()
) as xs:boolean {
    let $from := functx:time(5,30,0)
    let $until := functx:time(8,0,0)

    let $creationTime := functx:time(
            fn:hours-from-dateTime(analysis:getCreationTime($mba)),
            fn:minutes-from-dateTime(analysis:getCreationTime($mba)),
            fn:seconds-from-dateTime(analysis:getCreationTime($mba))
    )

    return
        if ($creationTime > $from and
            $creationTime < $until) then
                fn:true()
        else
            fn:false()
}:)

(:return analysis:getActualAverageLambda($mba, 'operationalInsurance', $timeFunc):)

let $n :=
<states>
    <state id="CheckFeasibility" factor='3'/>
    <state id='ChooseProducts' factor='7'/>
</states>
let $inState := 'End1'
let $toState := 'End1'
let $level := 'tacticalInsurance'

let $n1 :=
    <states>
        <state id="Archive_f" factor='3'/>
        <state id='CollectData' factor='7'/>
    </states>
let $inState1 := 'End2'
let $toState1 := 'Pay'
let $level1 := 'operationalInsurance'

(:$isInState('Archive_f') and $isInState('Print_f'):)

return analysis:getTotalCycleTime2($mba, $level1, $inState1, $toState1, $n1)

(: ################## Testcalls ################## :)

(:return sc:computeEntrySet($mbaOptCarClerk//sc:transition[@event="finishedCollecting"]):)

(:return analysis:getAverageCycleTime($mba, "tacticalInsurance", "End1", "ChooseProducts"):) (:15M:)

(:return analysis:getStateLog($mbaOptCarClerk):)

(:return analysis:getCycleTimeOfInstance($mbaTactCar, ()):) (:40M:)

(:return analysis:getTotalActualCycleTime($mba, "tacticalInsurance", "End1"):)(:35M:)

(:return analysis:getTotalCycleTimeInStates($mbaTactCar, "tacticalInsurance", ("ChooseProducts", "CheckFeasibility")):) (:15M:)

(:return analysis:getCreationTime($mba):)

(:return analysis:getTransitionProbability($transition):)

(: return analysis:compareEvents("hello", "hello123.blah") :)

(:let $scxml := analysis:getSCXMLAtLevel($mba, 'operationalInsurance')
let $state := $scxml//(sc:state|sc:parallel)[@id='Archive']
return analysis:getTransitionProbabilityForTargetState($scxml, $state, (), true(), true()):)

(:return analysis:getTransitionsToState($scxml, $state, true(), true()):)

