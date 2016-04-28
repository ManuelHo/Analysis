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
let $mbaOptHouseClerk := $testData//mba:mba[@name="MyHouseholdInsuranceClerk"]

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

(:let $n :=
<states>
    <state id="ImplementProduct" factor='3'/>
    <state id='CheckFeasibility' factor='3'/>
</states>
let $inState := 'End1'
let $toState := 'End1'
let $level := 'tacticalInsurance'
let $cTrans := (
    analysis:getSCXMLAtLevel($mba, $level)//sc:transition[@event = "startDevelopment"],
    analysis:getSCXMLAtLevel($mba, $level)//sc:transition[@event = "finishedCoding"]
)
let $cTransFactors :=
    (
        1,
        0.5
    )
let $stateList := analysis:getTotalCycleTimeToState($mba, $level, $inState, $toState, $n, $cTrans, $cTransFactors)
let $result := analysis:getCausesOfProblematicStates($mba, $level, $inState, true(), $n, $cTrans, $cTransFactors, 0.5)

let $n1 :=
    <states>
        <state id="Archive_f" factor='3'/>
        <state id='CollectData' factor='7'/>
    </states>
let $inState1 := 'End2'
let $toState1 := 'Pay'
let $level1 := 'operationalInsurance'
let $cTrans1 := analysis:getSCXMLAtLevel($mba, $level1)//sc:transition[@event="finishedCollecting"]
let $stateList1 := analysis:getTotalCycleTimeToState($mba, $level1, $inState1, $toState1, $n1, (), ())

let $state := $mba/mba:topLevel/mba:childLevel[@name='tacticalInsurance']/mba:elements/sc:scxml/sc:state[@id='DevelopProducts']

return $state:)

(:
return $stateList
:)
(:let $state1 := $mbaOptHouseClerk//sc:state[@id='Archive']

return element {'state'} {
    $state1/@id,
    if ($state1/(ancestor-or-self::sc:state | ancestor-or-self::sc:parallel | ancestor-or-self::sc:final)/@id = $n1/state/@id) then
        $n1/state[@id = $state1/(ancestor-or-self::sc:state | ancestor-or-self::sc:parallel | ancestor-or-self::sc:final)/@id]/@factor
    else
        $n1/state[@id = $state1/@id]/@factor
}:)



(: ################## Testcalls ################## :)

(:
return sc:computeEntrySet($mbaOptCarClerk//sc:transition[@event="finishedCollecting"])
:)


return analysis:getAverageCycleTime($mba, "tacticalInsurance", "End1", "ChooseProducts", ())


(:
return analysis:getStateLog($mbaOptCarClerk)
:)

(:
return analysis:getCycleTimeOfInstance($mbaTactCar, 'End1')
:)  (:25M:)

(:
return analysis:getTotalActualCycleTime($mba, "tacticalInsurance", "End1")
:)  (:35M:)

(:
return analysis:getTotalCycleTimeInStates($mbaTactCar, "tacticalInsurance", ("ChooseProducts", "CheckFeasibility"))
:)    (:15M:)

(:
return analysis:getCreationTime($mba)
:)

(:
let $transition := $mbaOptCarClerk//sc:transition[@event='done.state.Store']
return analysis:getTransitionProbability($transition, ())
:)  (:1:)


(:
return analysis:compareEvents("hello", "hello123.blah")
:)

(:
let $scxml := analysis:getSCXMLAtLevel($mba, 'operationalInsurance')
let $state := $scxml//(sc:state|sc:parallel)[@id='Print']
return analysis:getTransitionProbabilityForTargetState($scxml, $state, (), true(), true())
:)  (:0.5:)

(:
let $scxml := analysis:getSCXMLAtLevel($mba, 'operationalInsurance')
let $state := $scxml//sc:final[@id='Print_f']
return analysis:getTransitionsToState($scxml, $state, true(), true())
:)


(:
let $n :=
<states>
    <state id="CheckFeasibility" factor='3'/>
    <state id='ChooseProducts' factor='7'/>
</states>
let $inState := 'End1'
let $excludeArchiveStates := true()
let $level := 'tacticalInsurance'
return analysis:getTotalCycleTime($mba, $level, $inState, $excludeArchiveStates, $n, ())
:)

(:
let $n :=
    <states>
        <state id="CheckFeasibility" factor='10'/>
        <state id='ImplementProduct' factor='1'/>
    </states>
let $inState := 'End1'
let $toState := 'End1'
let $level := 'tacticalInsurance'
let $state := analysis:getSCXMLAtLevel($mba, $level)//*[@id='DevelopProducts']

return analysis:getCycleTimeForCompositeState($mba, $level, $inState, $state, $n, (), $toState)
:)

(: NOT WORKING, HAS TO BE UPDATED
let $n :=
<states>
    <state id="DevelopProducts" factor='3'/>
    <state id='ChooseProducts' factor='1'/>
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

let $cTrans := (
    analysis:getSCXMLAtLevel($mba, $level1)//sc:transition[@event = "finishedCollecting"],
    analysis:getSCXMLAtLevel($mba, $level1)//sc:transition[@event = "archived"]
)

let $cTrans2 := analysis:getSCXMLAtLevel($mba, $level1)//sc:transition[@event="finishedCollecting"]

let $stateList := analysis:getTotalCycleTimeToState($mba, $level1, $inState1, $toState1, $n1, $cTrans)
let $stateList1 := analysis:getTotalCycleTimeToState($mba, $level, $inState, $toState, $n, ())

return $stateList
:)

(:
let $n :=
<states>
    <state id="ImplementProduct" factor='3'/>
    <state id='CheckFeasibility' factor='3'/>
</states>
let $inState := 'End1'
let $toState := 'End1'
let $level := 'tacticalInsurance'
let $cTrans := (
    analysis:getSCXMLAtLevel($mba, $level)//sc:transition[@event = "startDevelopment"],
    analysis:getSCXMLAtLevel($mba, $level)//sc:transition[@event = "finishedCoding"]
)
let $cTransFactors :=
    (
        1,
        0.5
    )
let $stateList := analysis:getTotalCycleTimeToState($mba, $level, $inState, $toState, $n, $cTrans, $cTransFactors)
let $result := analysis:getCausesOfProblematicStates($mba, $level, $inState, true(), $n, $cTrans, $cTransFactors, 0.5)

let $n1 :=
    <states>
        <state id="Archive_f" factor='3'/>
        <state id='CollectData' factor='7'/>
    </states>
let $inState1 := 'End2'
let $toState1 := 'Pay'
let $level1 := 'operationalInsurance'
let $cTrans1 := analysis:getSCXMLAtLevel($mba, $level1)//sc:transition[@event="finishedCollecting"]
let $stateList1 := analysis:getTotalCycleTimeToState($mba, $level1, $inState1, $toState1, $n1, (), ())

return $result
:)