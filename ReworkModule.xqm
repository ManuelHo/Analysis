xquery version "3.0";

module namespace ReworkModule = "http://www.dke.jku.at/MBA/Rework";

declare namespace xes = 'http://www.xes-standard.org/';

import module namespace mba = 'http://www.dke.jku.at/MBA' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/mba.xqm';
import module namespace sc = 'http://www.w3.org/2005/07/scxml' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/scxml.xqm';
import module namespace functx = 'http://www.functx.com' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/functx.xqm';

declare function ReworkModule:isRework($scxml as element(),
    $transition as element()
){
    (: check if there is a path via $transition to mba:isArchiveState which does not enter $transition/source :)
    if ((fn:compare(fn:name(sc:getSourceState($transition)),'sc:initial')=0)) then
        'initial'
    else
        not(
            functx:is-value-in-sequence(
                false(),
                ReworkModule:isReworkRec($scxml, sc:getSourceState($transition)/@id, $transition)   (: ToDo: first call: what if target = source ? :)
            ) (: if there is no 'false' in sequence, this means no path to end without loop has been found :)
        )

};

(: true if transition is a rework loop, false if there is a path to end :)
declare function ReworkModule:isReworkRec($scxml as element(),
    $firstState as xs:string,
    $transition as element()
) {
        if (
            fn:compare($transition/@target, $firstState)=0
        ) then
            true() (: loop found :)
        else if (
            $scxml//*[@id=$transition/@target and @mba:isArchiveState]
        ) then
            false() (: end found, no rework loop :)
        else (: follow path ... :)
            let $transitions := $scxml//*[@id=$transition/@target]/sc:transition
            return (: ToDo: what if no transitions are leaving state? :)
                for $t in $transitions
                    return ReworkModule:isReworkRec($scxml, $firstState, $t)

};