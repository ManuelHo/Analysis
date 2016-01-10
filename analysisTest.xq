declare namespace xes='http://www.xes-standard.org/';
declare namespace sc='http://www.w3.org/2005/07/scxml';

import module namespace mba  = 'http://www.dke.jku.at/MBA';
import module namespace functx = 'http://www.functx.com';
import module namespace analysis='http://www.dke.jku.at/MBA/Analysis';
  
let $testData := fn:doc("Data/TestData.xml")

let $mba := $testData/mba:mba
let $mbaTactCar := $testData//mba:mba[@name="MyCarInsuranceCompany"]
let $mbaTactHouse := $testData//mba:mba[@name="MyHouseholdInsuranceCompany"]

let $mbaOptCarClerk := $testData//mba:mba[@name="MyCarInsuranceClerk"]

return sc:computeEntrySet($mbaOptCarClerk//sc:transition[@event="finishedCollecting"])

(:return analysis:averageCycleTime($mba, "tacticalInsurance", "End1", "ChooseProducts"):) (:15M:)

(:return analysis:getStateLog($mba):)

(:return analysis:getCycleTimeOfInstance($mbaTactCar, ():) (:40M:)

(:return analysis:getTotalActualCycleTime($mba, "tacticalInsurance", "End1"):)(:1H5M:)

(:return analysis:getTotalCycleTimeInStates($mbaTactCar, "tacticalInsurance", ("ChooseProducts", "CheckFeasibility")):) (:15M:)