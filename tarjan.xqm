xquery version "3.0";

module namespace tarjan = "http://www.dke.jku.at/MBA/Tarjan";

declare namespace xes = 'http://www.xes-standard.org/';

import module namespace mba = 'http://www.dke.jku.at/MBA' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/mba.xqm';
import module namespace sc = 'http://www.w3.org/2005/07/scxml' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/scxml.xqm';
import module namespace functx = 'http://www.functx.com' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/functx.xqm';

declare function tarjan:tarjanAlgorithm($scxml as element()
) as map(*) {
    fn:fold-left($scxml/sc:state, (: ToDo: all states of SCXML :)
            tarjan:createMap(0, (), (), (), ()),
            function($result, $state) {
                let $index := map:get($result, 'index')
                let $indexes := map:merge(map:get($result, 'indexes'))
                let $lowlinks := map:merge(map:get($result, 'lowlinks'))
                let $stack := map:get($result, 'stack')
                let $scc := map:get($result, 'scc')

                return
                    if (tarjan:notVisited($indexes, $state/@id)) then
                        tarjan:strongconnect($scxml, $state, $result)
                    else
                        $result
            })
};

declare function tarjan:strongconnect($scxml as element(),
        $state as element(),
        $resultMap as map(*)
) as map(*) {
    let $index := map:get($resultMap, 'index') (: next index :)
    let $indexes := map:merge((map:get($resultMap, 'indexes'), map:entry($state/@id, $index)))
    let $lowlink := $index
    let $lowlinks := map:merge(((map:get($resultMap, 'lowlinks'), map:entry($state/@id, $lowlink))))

    let $stack := (map:get($resultMap, 'stack'), $state) (: push :)
    let $scc := map:get($resultMap, 'scc')

    let $index := $index + 1

    (: consider successors of $state :)
    let $successors := $scxml//sc:state[@id = $scxml//sc:state[@id = $state/@id]/sc:transition/@target] (: ToDo: substates + only transitions leaving state :)

    let $recursiveResult :=
        fn:fold-left($successors,
                tarjan:createMap($index, $indexes, $lowlinks, $stack, $scc),
                function($result, $successor) {
                    if (tarjan:notVisited($indexes, $successor/@id)) then
                    (: $successor has not yet been visited; recurse on it :)
                        let $sucResult := tarjan:strongconnect($scxml, $successor, $result)
                        (: min($state.lowlink, $successor.lowlink) :)
                        let $lowlinks := map:get($sucResult, 'lowlinks')
                        let $lowlink := min((
                            map:get($lowlinks, $state/@id),
                            map:get($lowlinks, $successor/@id)
                        ))
                        return
                            tarjan:createMap(map:get($sucResult, 'index'),
                                    map:get($sucResult, 'indexes'),
                                    map:merge((($lowlinks, map:entry($state/@id, $lowlink)))),
                                    map:get($sucResult, 'stack'),
                                    map:get($sucResult, 'scc')
                            )
                    else if (tarjan:onStack($stack, $successor)) then
                    (: $successor is in stack and hence in the current SCC :)
                        let $indexes := map:get($result, 'indexes')
                        let $lowlinks := map:get($result, 'lowlinks')
                        let $lowlink := min((
                            map:get($lowlinks, $state/@id),
                            map:get($indexes, $successor/@id)
                        ))
                        return
                            tarjan:createMap(
                                    map:get($result, 'index'),
                                    map:get($result, 'indexes'),
                                    map:merge((($lowlinks, map:entry($state/@id, $lowlink)))),
                                    map:get($result, 'stack'),
                                    map:get($result, 'scc')
                            )
                    else
                        $result
                }
        )

    let $index := map:get($recursiveResult, 'index')
    let $indexes := map:get($recursiveResult, 'indexes')
    let $lowlinks := map:get($recursiveResult, 'lowlinks')
    let $stack := map:get($recursiveResult, 'stack')
    let $scc := map:merge(map:get($recursiveResult, 'scc'))

    return
    (: if $lowlink = $index (i.e. root node), return SCC and pop from stack :)
        if (map:get($lowlinks, $state/@id) = map:get($indexes, $state/@id)) then
            let $map := tarjan:popStack($stack, (), $state)
            let $newStack := map:get($map, 'stack')
            let $newScc := map:get($map, 'scc')
            return
                tarjan:createMap($index, $indexes, $lowlinks, $newStack, map:merge(($scc, map:entry(map:size($scc), $newScc))))
        else
            tarjan:createMap($index, $indexes, $lowlinks, $stack, $scc)
};

declare function tarjan:createMap($index as xs:integer, (: global index :)
        $indexes as map(*)?, (: mapping of state to index :)
        $lowlinks as map(*)?, (: mapping of state to lowlinks :)
        $stack as element()*, (: sequence which simulates stack :)
        $scc as map(*)?(: strongly connected components :)
) as map(*) {
    map:merge((
        map:entry('index', $index),
        map:entry('indexes', $indexes),
        map:entry('lowlinks', $lowlinks),
        map:entry('stack', $stack),
        map:entry('scc', $scc)
    ))
};

declare function tarjan:notVisited($indexes as map(*),
        $state as xs:string
) as xs:boolean {
    fn:empty(map:get($indexes, $state))
};

declare function tarjan:onStack($stack as element()*,
        $state as element()
) as xs:boolean {
    functx:is-node-in-sequence($state, $stack)
};

declare function tarjan:popStack($stack as element()*,
        $scc as element()*,
        $state as element()
) as map(*) {
(: pop until $stack.pop = $state :)
    let $s := $stack[last()]
    let $stack := $stack[position() != last()]
    let $scc := ($scc, $s)

    return
        if ($s is $state) then
            map:merge((
                map:entry('stack', $stack),
                map:entry('scc', $scc)
            ))
        else
            tarjan:popStack($stack, $scc, $state)
};