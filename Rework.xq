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
            <sc:transition event="toB" target="B"/>
        </sc:state>
        <sc:state id="B">
            <sc:transition event="toF" target="F"/>
            <sc:transition event="toC" target="C"/>
        </sc:state>
        <sc:state id="C">
            <sc:transition event="toD" target="D"/>
            <sc:transition event="toA" target="A"/>
            <sc:transition event="toF1" target="F"/>
        </sc:state>
        <sc:state id="D">
            <sc:transition event="toA1" target="A"/>
        </sc:state>
        <sc:state id="F" mba:isArchiveState="true"/>
    </sc:scxml>

let $state := $scxml//sc:state[@id="A"]
let $scc := analysis:getSCCForRootNode($scxml, $state)

let $testData := fn:doc("C:/Users/manue/Masterarbeit/Analysis/Data/Rework.xml")
let $mba := $testData/mba:mba
let $mbaSub1 := $testData//mba:mba[@name = "MyReworkTestSub1"]
let $level := 'l2'
let $stateId := 'S2'
let $ctS2 := analysis:getAverageCycleTime($mba, 'l2', (), 'S2')
let $scxml := analysis:getSCXMLAtLevel($mba, 'l2')
let $state := $scxml//sc:state[@id='S2']
let $scc := analysis:getSCCForRootNode($scxml, $state)

(:let $sccMap := tarjan:tarjanAlgorithm($scxml)
let $allSCCs := fn:for-each(map:keys($sccMap), function($k){map:get($sccMap, $k)})
:)

let $prob := analysis:getTransitionProbabilityForTargetState($scxml, $state, (), (), true(), true())
let $ctTotal := analysis:getTotalCycleTime($mba, 'l2', (), (), (), (), ())

let $stateList := analysis:getStateList($mba, $level, (), $state, (), (), (), ())

return $scc
