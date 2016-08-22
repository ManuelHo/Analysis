xquery version "3.0";

declare namespace xes='http://www.xes-standard.org/';

import module namespace mba  = 'http://www.dke.jku.at/MBA' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/mba.xqm';
import module namespace functx = 'http://www.functx.com' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/functx.xqm';
import module namespace analysis='http://www.dke.jku.at/MBA/Analysis' at 'C:/Users/manue/Masterarbeit/Analysis/analysis.xqm';

import module namespace sc='http://www.w3.org/2005/07/scxml' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/scxml.xqm';

let $testData := fn:doc("C:/Users/manue/Masterarbeit/Analysis/Data/TestData.xml")

let $mba := $testData/mba:mba
let $level := 'tacticalInsurance'

let $scxml := analysis:getSCXMLAtLevel($mba, $level)
let $stateId := 'ImplementProduct'

let $s :=
    <s>
        <state id="CheckFeasibility" averageCycleTime="PT16M40S"/>
        <state id="ChooseProducts" averageCycleTime="PT16M40S"/>
        <state id="ImplementProduct" averageCycleTime="PT2H13M19.9999999999992S"/>
        <state id="DevelopProducts" averageCycleTime="PT13H20M20S"/>
    </s>

let $stateList := $s/state





let $stateLog :=
    <stateLog>
        <state until="2019-01-01T07:40:00+02:00" ref="ChooseProducts" from="2016-01-01T07:30:00+02:00"/>
        <state until="2016-01-01T07:45:00+02:00" ref="CheckFeasibility" from="2016-01-01T07:40:00+02:00"/>
        <state until="2016-01-01T07:55:00+02:00" ref="DevelopProducts" from="2016-01-01T07:40:00+02:00"/>
        <state until="2016-01-01T07:55:00+02:00" ref="ImplementProduct" from="2016-01-01T07:45:00+02:00"/>
        <state ref="End1" from="2016-01-01T07:55:00+02:00"/>
    </stateLog>

let $duration := xs:dateTime($stateLog/state[@ref="ChooseProducts"]/@until) - xs:dateTime($stateLog/state[@ref="ChooseProducts"]/@from)

let $e := element{"test"}{
    attribute time {
        $duration
    }
}

(:return fn:sum($e/@time):)

let $t := "P2000Y12MT23H12M34S"

let $source :=
    <tr>
        <t id="x"/>
        <t id="y"/>
        <t id="z"/>
    </tr>


let $trans := $source/t

let $factors :=
    (
        4,
        5,
        6
    )

let $t := $source/t[@id="y"]

let $f := $factors[position() = functx:index-of-node($trans, $t)]

let $subMap := map:merge((map:entry(1, 2), map:entry(2, 3)))
let $map := map:merge((map:entry(1, $subMap)))

let $m := map:get(map:get($map, 1), 1)

let $x := "-->[I],[SW]"

let $a := <a></a>

let $n := <a id="1"/>
let $cycleTime := ($n, <a id="2"/>)

let $string := "$_everyDescendantAtLevelIsInState('levelName', 'StateId')"
let $string2 := "$_everyDescendantAtLevelIsInState('functi''(),,on', 'levelName', 'StateId')"

let $levelName := fn:substring-before(fn:substring-after($string, "'"), "'")
let $stateId := fn:substring-before(fn:substring-after(fn:substring-after($string, ","), "'"), "'")

let $a := fn:doc("C:/Users/manue/Masterarbeit/Analysis/Data/eval.xml")//x

let $stateLog := analysis:getStateLog($mba)

let $o := false()

let $testData := fn:doc("C:/Users/manue/Masterarbeit/Analysis/Data/Synchronization.xml")
let $mba := $testData/mba:mba
let $level := "l2"

let $transition := analysis:getSCXMLAtLevel($mba, $level)//sc:state[@id="SX"]//sc:transition
let $state := analysis:getSCXMLAtLevel($mba, $level)//sc:state[@id="SX"]
let $sourceTransition := fn:string(sc:getSourceState($transition)/@id)
let $targetTransition := fn:string($transition/@target)
let $scxml := $transition/ancestor::sc:scxml[1]
let $stateAndSubstates := analysis:getStateAndSubstates($scxml, $state)

return
    (
        analysis:stateIsLeft($transition, $state/@id)
        ,
        (:analysis:getSCXMLAtLevel($mba, $level)
        ,:)
        $scxml//(sc:state | sc:parallel | sc:final)[@id = "SX"]/(descendant-or-self::sc:state | descendant-or-self::sc:parallel | descendant-or-self::sc:final)/fn:string(@id)
    )

