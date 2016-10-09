(:
 : This file contains various test requests for main functions of the
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


let $ct := analysis:getCycleTimeOfInstance($mbaTactCar, 'End1')

let $stateLog := analysis:getStateLog($mbaTactCar)/state

return $ct