xquery version "3.0";

declare namespace xes = 'http://www.xes-standard.org/';

import module namespace mba = 'http://www.dke.jku.at/MBA' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/mba.xqm';
import module namespace functx = 'http://www.functx.com' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/functx.xqm';
import module namespace analysis = 'http://www.dke.jku.at/MBA/Analysis' at 'C:/Users/manue/Masterarbeit/Analysis/analysis.xqm';
import module namespace rework = 'http://www.dke.jku.at/MBA/Rework' at 'C:/Users/manue/Masterarbeit/Analysis/ReworkModule.xqm';
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
            <sc:transition event="toA" target="A"/>
            <sc:transition event="toB1" target="B"/>
        </sc:state>
        <sc:state id="D" mba:isArchiveState="true"/>
    </sc:scxml>

let $x :=
    (
        1,
        2,
        3,
        $index
    )
let $z :=
    for $i in $x
    let $index := $index+1
    return 1

let $x := ($x, 4)
let $y := $x[last()]
let $x := $x[position()!=last()]

let $m :=
    map:merge((
        map:entry('S1', 3),
        map:entry('S2', 2)
    ))

let $result := tarjan:tarjanAlgorithm($scxml)
let $low := map:get(map:get($result, 'lowlinks'), 'D')

let $stack := map:get($result, 'stack')

let $scc := map:get(map:get($result, 'scc'), 2)

return $scc