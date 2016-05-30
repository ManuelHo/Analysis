xquery version "3.0";

declare namespace xes = 'http://www.xes-standard.org/';

import module namespace mba = 'http://www.dke.jku.at/MBA' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/mba.xqm';
import module namespace functx = 'http://www.functx.com' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/functx.xqm';
import module namespace analysis = 'http://www.dke.jku.at/MBA/Analysis' at 'C:/Users/manue/Masterarbeit/Analysis/analysis.xqm';
import module namespace tarjan = 'http://www.dke.jku.at/MBA/Tarjan' at 'C:/Users/manue/Masterarbeit/Analysis/tarjan.xqm';

import module namespace sc = 'http://www.w3.org/2005/07/scxml' at 'C:/Users/manue/Masterarbeit/Analysis/MBAse/scxml.xqm';

declare variable $index := 0;

let $testData := fn:doc("C:/Users/manue/Masterarbeit/Analysis/Data/MultipleEntries.xml")
let $mba := $testData/mba:mba
let $mbaSub1 := $testData//mba:mba[@name = "MyReworkTestSub1"]
let $level := 'l2'
let $state := 'B'

let $ct := analysis:getAverageCycleTime($mba, $level, (), $state, ())
let $scxml := analysis:getSCXMLAtLevel($mba, 'l2')
let $state := $scxml//sc:state[@id='E']
let $scc := analysis:getSCCForRootNode($scxml, $state)

let $prob := analysis:getTransitionProbabilityForTargetState($scxml, $state, (), (), (), true(), true())

return $prob