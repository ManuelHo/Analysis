xquery version "3.0";

declare namespace xes = 'http://www.xes-standard.org/';

import module namespace mba = 'http://www.dke.jku.at/MBA' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/mba.xqm';
import module namespace functx = 'http://www.functx.com' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/functx.xqm';
import module namespace analysis = 'http://www.dke.jku.at/MBA/Analysis' at 'C:/Users/manue/Masterarbeit/Analysis/analysis.xqm';
import module namespace tarjan = 'http://www.dke.jku.at/MBA/Tarjan' at 'C:/Users/manue/Masterarbeit/Analysis/tarjan.xqm';

import module namespace sc = 'http://www.w3.org/2005/07/scxml' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/scxml.xqm';

declare variable $index := 0;

let $scxml :=
    <sc:scxml>
        <sc:initial>
            <sc:transition target="A"/>
        </sc:initial>
        <sc:state id="A">
            <sc:transition event="toB0" target="B"/>
            <sc:transition event="toC" target="C"/>
        </sc:state>
        <sc:state id="B">
            <sc:transition event="toD" target="D"/>
        </sc:state>
        <sc:state id="C">
            <sc:transition event="toE" target="E"/>
            <sc:transition event="toB1" target="B"/>
        </sc:state>
        <sc:state id="E">
            <sc:transition event="toA" target="A"/>
        </sc:state>
        <sc:state id="D" mba:isArchiveState="true"/>
    </sc:scxml>

let $scc := tarjan:tarjanAlgorithm($scxml)

let $testData := fn:doc("C:/Users/manue/Masterarbeit/Analysis/Data/Rework.xml")
let $mba := $testData/mba:mba
let $mbaSub1 := $testData//mba:mba[@name="MyReworkTestSub1"]

let $level := 'l2'
let $stateId := 'S2'

let $ctS2 := analysis:getAverageCycleTime($mba, 'l2', (), 'S2', ())
(:let $ctTotal := analysis:getTotalCycleTime($mba, 'l2', (), (), (), (), ()):) (: stack overflow :)

let $scxml := analysis:getSCXMLAtLevel($mba, 'l2')
let $scc := tarjan:tarjanAlgorithm($scxml)

return fn:for-each(map:keys($scc), function($k){map:get($scc, $k)})