(:
 : This file contains tests for the tarjan algorithm
 :)

xquery version "3.0";

declare namespace xes = 'http://www.xes-standard.org/';

import module namespace mba = 'http://www.dke.jku.at/MBA';
import module namespace functx = 'http://www.functx.com';
import module namespace analysis = 'http://www.dke.jku.at/MBA/Analysis';
import module namespace sc = 'http://www.w3.org/2005/07/scxml';

(: find strongly connected component with state 'A' as root :)
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
let $scc := analysis:getSCCForRootNodeTarjan($scxml, $state)

(: get cycle time of process model with loop :)
let $testData := db:open("Rework")
let $mba := $testData/mba:mba
let $level := 'l2'
let $totalCycleTimeToState := analysis:getTotalCycleTimeToState($mba, $level, (), 'S7', (), (), ())

(: transition probability of root node from scc :)
let $scxml := analysis:getSCXMLAtLevel($mba, 'l2')
let $state := $scxml//sc:state[@id='S2']
let $sccMap := analysis:tarjanAlgorithm($scxml)
let $prob := analysis:getTransitionProbabilityForTargetState($scxml, $state, (), (), $sccMap)

return $prob

