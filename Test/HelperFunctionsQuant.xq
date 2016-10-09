(:
 : This file contains various test requests for helper functions of the
 : module "analysis.xqm".
 : Requires DB "TestData" or "Data/TestData.xml".
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

(: cycle time of composite state 'DevelopProducts' using changed states :)
let $n :=
    <states>
        <state id="CheckFeasibility" factor='10'/>
        <state id='ImplementProduct' factor='1'/>
    </states>
let $inState := 'End1'
let $level := 'tacticalInsurance'
let $state := analysis:getSCXMLAtLevel($mba, $level)//*[@id='DevelopProducts']
let $cycleTimeOfCompositeState := analysis:getCycleTimeForCompositeState($mba, $level, $inState, $state, $n, (), ())

(: get transitions to state 'Print_f' :)
let $scxml := analysis:getSCXMLAtLevel($mba, 'operationalInsurance')
let $state := $scxml//sc:final[@id='Print_f']
let $transitionsToState := analysis:getTransitionsToState($scxml, $state, true(), true())

return $transitionsToState