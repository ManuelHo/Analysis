xquery version "3.0";

declare namespace xes='http://www.xes-standard.org/';

import module namespace mba  = 'http://www.dke.jku.at/MBA' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/mba.xqm';
import module namespace functx = 'http://www.functx.com' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/functx.xqm';
import module namespace analysis='http://www.dke.jku.at/MBA/Analysis' at 'C:/Users/manue/Masterarbeit/Analysis/analysis.xqm';
import module namespace rework='http://www.dke.jku.at/MBA/Rework' at 'C:/Users/manue/Masterarbeit/Analysis/ReworkModule.xqm';

import module namespace sc='http://www.w3.org/2005/07/scxml' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/scxml.xqm';

let $scxml :=
    <sc:scxml>
        <sc:initial>
            <sc:transition target="A"/>
        </sc:initial>
        <sc:state id="A">
            <sc:transition event="toB" target="B"/>
            <sc:transition event="rC" target="C"/>
        </sc:state>
        <sc:state id="B">
            <sc:transition event="toD" target="D"/>
        </sc:state>
        <sc:state id="C">
            <sc:transition event="rE" target="E"/>
        </sc:state>
        <sc:state id="E">
            <sc:transition event="rA" target="A"/>
        </sc:state>
        <sc:state id="D" mba:isArchiveState="true"/>
    </sc:scxml>

let $transition := $scxml//sc:transition[@event='rC']

return
    for $t in $scxml//sc:transition
        return
            copy $new := $t modify (
                insert node attribute rework {rework:isRework($scxml, $t)} into $new
            ) return $new
