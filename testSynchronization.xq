xquery version "3.0";

declare namespace xes='http://www.xes-standard.org/';

import module namespace mba  = 'http://www.dke.jku.at/MBA' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/mba.xqm';
import module namespace functx = 'http://www.functx.com' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/functx.xqm';
import module namespace analysis='http://www.dke.jku.at/MBA/Analysis' at 'C:/Users/manue/Masterarbeit/Analysis/analysis.xqm';

import module namespace sc='http://www.w3.org/2005/07/scxml' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/scxml.xqm';

let $testData := fn:doc("C:/Users/manue/Masterarbeit/Analysis/Data/Synchronization.xml")

let $mba := $testData/mba:mba
let $mbaTop := $testData//mba:mba[@name="MySynchronizationTest"]
let $mbaSub1 := $testData//mba:mba[@name="MySynchronizationTestSub1"]
let $mbaSub2 := $testData//mba:mba[@name="MySynchronizationTestSub2"]
let $mbaSub3 := $testData//mba:mba[@name="MySynchronizationTestSub3"]

let $testDataAnc := fn:doc("C:/Users/manue/Masterarbeit/Analysis/Data/SynchronizationAncestor.xml")
let $mbaAnc := $testDataAnc/mba:mba

let $changedStates :=
    <states>
        <state id="S1" factor='1'/>
        <state id='S2' factor='1'/>
    </states>
let $inState := 'S4'
let $toState := 'S4'
let $level := 'l1'
let $cTrans := (
    analysis:getSCXMLAtLevel($mba, $level)//sc:transition[@event = "t1"],
    analysis:getSCXMLAtLevel($mba, $level)//sc:transition[@event = "t2"]
)
let $cTransFactors :=
    (
        1,
        1
    )

let $cycleTime := analysis:getTotalCycleTime($mba, $level, $inState, true(), (), (), ())
let $problems := analysis:getCausesOfProblematicStates($mba, $level, $inState, true(), 0.3)
let $problemStates := analysis:getProblematicStates($mba, $level, $inState, true(), 0.3)

let $stateLog := analysis:getStateLog($mba)
let $time1 := $stateLog/state[@ref='S2']/@until
let $time2 := $stateLog/state[@ref='S3']/@until

let $same := analysis:timesAreSame(xs:dateTime($time1), xs:dateTime($time2))

let $times := (xs:dateTime($time2), xs:dateTime($time1))

return
    (
        fn:concat('Total: ', $cycleTime)
        ,
        $problems
    )