(:
 : This file contains a test about a MBA with a loop which has multiple entries
 : Such models can not be calculated correctly!
 :)
xquery version "3.0";

declare namespace xes = 'http://www.xes-standard.org/';

import module namespace mba = 'http://www.dke.jku.at/MBA';
import module namespace functx = 'http://www.functx.com';
import module namespace analysis = 'http://www.dke.jku.at/MBA/Analysis';
import module namespace sc = 'http://www.w3.org/2005/07/scxml';

let $testData := db:open("MultipleEntries")
let $mba := $testData/mba:mba
let $mbaSub1 := $testData//mba:mba[@name = "MyReworkTestSub1"]
let $level := 'l2'
let $state := 'B'

let $ct := analysis:getAverageCycleTime($mba, $level, (), $state)
let $scxml := analysis:getSCXMLAtLevel($mba, 'l2')
let $state := $scxml//sc:state[@id='E']
let $sccMap := analysis:tarjanAlgorithm($scxml)

let $prob := analysis:getTransitionProbabilityForTargetState($scxml, $state, (), (), $sccMap)

return $prob