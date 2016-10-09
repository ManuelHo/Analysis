(:
 : This file contains some test requests for demonstration
 :)
xquery version "3.0";

import module namespace mba = 'http://www.dke.jku.at/MBA';
import module namespace analysis = 'http://www.dke.jku.at/MBA/Analysis';

let $mba := db:open("TestData")/mba:mba
let $mbaQualitative := db:open("Synchronization")/mba:mba

let $excludeArchiveStates := true()
let $changedStates :=
    <states>
        <state id='ChooseProducts' factor='2'/>
    </states>
return
    (
        "### Quantitative Analysis ###",
        fn:concat("Avg. cycle time 'ChooseProducts':    ",
                analysis:getAverageCycleTime($mba,
                        "tacticalInsurance",
                        "End1", "ChooseProducts")
        ),
        fn:concat("Actual cycle time tact. level:       ",
                analysis:getTotalActualCycleTime($mba,
                        "tacticalInsurance", "End1")
        ),
        fn:concat("What-if analysis:                    ",
                analysis:getTotalCycleTime($mba,
                        "tacticalInsurance",
                        'End1', $excludeArchiveStates,
                        $changedStates, (), ())
        ),
        "-----------------------------------------------",
        "### Qualitative Analysis ###",
        analysis:getProblematicStates($mbaQualitative,
                'l1', 'S4', $excludeArchiveStates, 0.3),
        "--",
        analysis:getCausesOfProblematicStates($mbaQualitative,
                'l1', 'S4', $excludeArchiveStates, 0.3)
    )