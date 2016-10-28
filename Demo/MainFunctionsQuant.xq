(:
 : This file contains various test requests for main functions of the
 : module "analysis.xqm".
 :)

xquery version "3.0";

declare namespace xes='http://www.xes-standard.org/';

import module namespace mba  = 'http://www.dke.jku.at/MBA';
import module namespace functx = 'http://www.functx.com';
import module namespace analysis='http://www.dke.jku.at/MBA/Analysis';
import module namespace sc='http://www.w3.org/2005/07/scxml';

let $testData := db:open("TestData")

let $mba := $testData/mba:mba
let $mbaTactCar := $testData//mba:mba[@name="MyCarInsuranceCompany"]
let $mbaTactHouse := $testData//mba:mba[@name="MyHouseholdInsuranceCompany"]
let $mbaOptCarClerk := $testData//mba:mba[@name="MyCarInsuranceClerk"]
let $mbaOptHouseClerk := $testData//mba:mba[@name="MyHouseholdInsuranceClerk"]

(: cycle time $mbaTactCar (instance = topLevel) until state 'End1' is reached :)
let $cycleTimeOfInstance := analysis:getCycleTimeOfInstance($mbaTactCar, 'End1')

(: cycle time of $mba at level 'tacticalInsurance' until state 'End1' is reached :)
let $totalActualCycleTime := analysis:getTotalActualCycleTime($mba, 'tacticalInsurance', 'End1')

(: average cycle time of state 'ChooseProducts' on level 'tacticalIsurance' of concretizations from $mba who are in state 'End1' :)
let $averageCycleTime := analysis:getAverageCycleTime($mba, 'tacticalInsurance', 'End1', 'ChooseProducts')

(: cycle time of the states 'ChooseProducts' and 'CheckFeasibility' in instance $mbaTactCar :)
let $totalCycleTimeInStates := analysis:getTotalCycleTimeInStates($mbaTactCar, ('ChooseProducts', 'CheckFeasibility'))

(: total cycle time of $mba's level 'tacticalInsurance' with changed states, no changed transitions
 :)
let $n :=
  <states>
      <state id="CheckFeasibility" factor='3'/>
      <state id='ChooseProducts' factor='7'/>
  </states>
let $inState := 'End1'
let $excludeArchiveStates := true()
let $level := 'tacticalInsurance'
let $totalCycleTime := analysis:getTotalCycleTime($mba, $level, $inState, $excludeArchiveStates, $n, (), ())

(:
 : total cycle time of $mba's level 'operationalInsurance' with changed states + transitions
 :)
let $n :=
    <states>
        <state id="Archive_f" factor='3'/>
        <state id='CollectData' factor='7'/>
    </states>
let $inState := 'End2'
let $toState := 'Pay'
let $level := 'operationalInsurance'
let $cTrans :=
  (
    analysis:getSCXMLAtLevel($mba, $level)//sc:transition[@event="finishedCollecting"]
    ,
    analysis:getSCXMLAtLevel($mba, $level)//sc:transition[@event="archived"]
  )
let $cTransFactors := (10, 0.5)
let $totalCycleTimeToState := analysis:getTotalCycleTimeToState($mba, $level, $inState, $toState, $n, $cTrans, $cTransFactors)

return $totalCycleTimeToState








