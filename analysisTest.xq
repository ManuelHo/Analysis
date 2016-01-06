declare namespace xes='http://www.xes-standard.org/';
declare namespace sc='http://www.w3.org/2005/07/scxml';

import module namespace mba  = 'http://www.dke.jku.at/MBA';
import module namespace functx = 'http://www.functx.com';
import module namespace analysis='http://www.dke.jku.at/MBA/Analysis';

let $mba :=
<mba xmlns="http://www.dke.jku.at/MBA" xmlns:sync="http://www.dke.jku.at/MBA/Synchronization" xmlns:sc="http://www.w3.org/2005/07/scxml" name="MyInsuranceCompany" hierarchy="simple">
  <topLevel name="strategicInsurance">
  <elements>
      <sc:scxml name="StrategicInsurance">
        <sc:datamodel>
          <sc:data id="description">Insurance company which handles incidents</sc:data>
          <sc:data id="_event"/>
          <sc:data id="_x">
            <db xmlns="">myMBAse</db>
            <collection xmlns="">MyInsuranceCompany</collection>
            <mba xmlns="">MyInsuranceCompany</mba>
            <currentStatus xmlns="">
              <state ref="Working"/>
            </currentStatus>
            <externalEventQueue xmlns=""/>
      <xes:log xmlns:xes="http://www.xes-standard.org/">
        <xes:trace>
          <xes:event>
            <xes:date key="time:timestamp" value="2016-01-01T06:00:00.000+02:00"/>
            <xes:string key="sc:initial" value="StrategicInsurance"/>
            <xes:string key="sc:target" value="Working"/>
          </xes:event>
          <xes:event>
            <xes:date key="time:timestamp" value="2016-01-01T07:00:00.500+02:00"/>
            <xes:string key="sc:state" value="Working"/>
            <xes:string key="concept:name" value="handleIncident"/>
            <xes:string key="sc:event" value="handleIncident"/>
          </xes:event>
          <xes:event>
            <xes:date key="time:timestamp" value="2016-01-01T08:00:00.500+02:00"/>
            <xes:string key="sc:state" value="Working"/>
            <xes:string key="concept:name" value="handleIncident"/>
            <xes:string key="sc:event" value="handleIncident"/>
          </xes:event>
        </xes:trace>
      </xes:log>
          </sc:data>
        </sc:datamodel>
        <sc:initial>
          <sc:transition target="Working"/>
        </sc:initial>
        <sc:state id="Working">
          <sc:transition event="handleIncident"/>
      <sc:transition event="closeCompany" target="Closed"/>
        </sc:state>
    <sc:state id="Closed">
    </sc:state>
      </sc:scxml>
    </elements>
  <childLevel name="tacticalInsurance">
    <elements>
      <sc:scxml name="TacticalInsurance">
        <sc:datamodel>
          <sc:data id="_event"/>
          <sc:data id="_x">
          </sc:data>
        </sc:datamodel>
        <sc:initial>
          <sc:transition target="ChooseProducts"/>
        </sc:initial>
        <sc:state id="ChooseProducts">
          <sc:transition event="collectInformation"/>
          <sc:transition event="startDeveloping" target="CheckFeasibility"/>
        </sc:state>
        <sc:state id="DevelopProducts">
          <sc:state id="CheckFeasibility">
            <sc:transition event="startCoding" target="ImplementProduct"/>
            <sc:transition event="abortDevelopment" target="End1"/>
          </sc:state>
          <sc:state id="ImplementProduct">
            <sc:transition event="finishedCoding" target="End1"/>
          </sc:state>
        </sc:state>
        <sc:state id="End1">
        </sc:state>
      </sc:scxml>
    </elements>
    <childLevel name="operationalInsurance">
      
    </childLevel>
  </childLevel>
  </topLevel>
  <concretizations>
  <mba xmlns="http://www.dke.jku.at/MBA" xmlns:sync="http://www.dke.jku.at/MBA/Synchronization" xmlns:sc="http://www.w3.org/2005/07/scxml" name="MyCarInsuranceCompany" hierarchy="simple">
    <topLevel name="tacticalInsurance">
      <elements>
        <sc:scxml name="TacticalInsurance">
          <sc:datamodel>
            <sc:data id="_event"/>
            <sc:data id="_x">
              <db xmlns="">myMBAse</db>
              <collection xmlns="">MyInsuranceCompany</collection>
              <mba xmlns="">MyCarInsuranceCompany</mba>
              <currentStatus xmlns="">
                <state ref="End1"/>
              </currentStatus>
              <externalEventQueue xmlns=""/>
              <xes:log xmlns:xes="http://www.xes-standard.org/">
                <xes:trace>
                  <xes:event>
                    <xes:date key="time:timestamp" value="2016-01-01T07:30:00.000+02:00"/>
                    <xes:string key="sc:initial" value="TacticalInsurance"/>
                    <xes:string key="sc:target" value="ChooseProducts"/>
                  </xes:event>
                  <xes:event>
                    <xes:date key="time:timestamp" value="2016-01-01T07:35:00.000+02:00"/>
                    <xes:string key="sc:state" value="ChooseProducts"/>
                    <xes:string key="concept:name" value="collectInformation"/>
                    <xes:string key="sc:event" value="collectInformation"/>
                  </xes:event>
                  <xes:event>
                    <xes:date key="time:timestamp" value="2016-01-01T07:40:00.000+02:00"/>
                    <xes:string key="sc:state" value="ChooseProducts"/>
                    <xes:string key="concept:name" value="startDeveloping"/>
                    <xes:string key="sc:event" value="startDeveloping"/>
                    <xes:string key="sc:target" value="CheckFeasibility"/>
                  </xes:event>
                  <xes:event>
                    <xes:date key="time:timestamp" value="2016-01-01T07:45:00.000+02:00"/>
                    <xes:string key="sc:state" value="CheckFeasibility"/>
                    <xes:string key="concept:name" value="startCoding"/>
                    <xes:string key="sc:event" value="startCoding"/>
                    <xes:string key="sc:target" value="ImplementProduct"/>
                  </xes:event>
                  <xes:event>
                    <xes:date key="time:timestamp" value="2016-01-01T07:55:00.000+02:00"/>
                    <xes:string key="sc:state" value="ImplementProduct"/>
                    <xes:string key="concept:name" value="finishedCoding"/>
                    <xes:string key="sc:event" value="finishedCoding"/>
                    <xes:string key="sc:target" value="End1"/>
                  </xes:event>
                </xes:trace>
              </xes:log>
            </sc:data>
          </sc:datamodel>
          <sc:initial>
            <sc:transition target="ChooseProducts"/>
          </sc:initial>
          <sc:state id="ChooseProducts">
            <sc:transition event="collectInformation"/>
            <sc:transition event="startDeveloping" target="CheckFeasibility"/>
          </sc:state>
          <sc:state id="DevelopProducts">
            <sc:state id="CheckFeasibility">
              <sc:transition event="startCoding" target="ImplementProduct"/>
              <sc:transition event="abortDevelopment" target="End1"/>
            </sc:state>
            <sc:state id="ImplementProduct">
              <sc:transition event="finishedCoding" target="End1"/>
            </sc:state>
          </sc:state>
          <sc:state id="End1">
          </sc:state>
        </sc:scxml>
      </elements>
      <childLevel>
      </childLevel>
    </topLevel>
    <concretizations>
    </concretizations>
  </mba>
  <mba xmlns="http://www.dke.jku.at/MBA" xmlns:sync="http://www.dke.jku.at/MBA/Synchronization" xmlns:sc="http://www.w3.org/2005/07/scxml" name="MyHouseholdInsuranceCompany" hierarchy="simple">
    <topLevel name="tacticalInsurance">
      <elements>
        <sc:scxml name="TacticalInsurance">
          <sc:datamodel>
            <sc:data id="_event"/>
            <sc:data id="_x">
              <db xmlns="">myMBAse</db>
              <collection xmlns="">MyInsuranceCompany</collection>
              <mba xmlns="">MyHouseholdInsuranceCompanyInsuranceCompany</mba>
              <currentStatus xmlns="">
                <state ref="End1"/>
              </currentStatus>
              <externalEventQueue xmlns=""/>
              <xes:log xmlns:xes="http://www.xes-standard.org/">
                <xes:trace>
                  <xes:event>
                    <xes:date key="time:timestamp" value="2016-01-01T07:30:00.000+02:00"/>
                    <xes:string key="sc:initial" value="TacticalInsurance"/>
                    <xes:string key="sc:target" value="ChooseProducts"/>
                  </xes:event>
                  <xes:event>
                    <xes:date key="time:timestamp" value="2016-01-01T07:37:00.000+02:00"/>
                    <xes:string key="sc:state" value="ChooseProducts"/>
                    <xes:string key="concept:name" value="collectInformation"/>
                    <xes:string key="sc:event" value="collectInformation"/>
                  </xes:event>
                  <xes:event>
                    <xes:date key="time:timestamp" value="2016-01-01T07:50:00.000+02:00"/>
                    <xes:string key="sc:state" value="ChooseProducts"/>
                    <xes:string key="concept:name" value="startDeveloping"/>
                    <xes:string key="sc:event" value="startDeveloping"/>
                    <xes:string key="sc:target" value="CheckFeasibility"/>
                  </xes:event>
                  <xes:event>
                    <xes:date key="time:timestamp" value="2016-01-01T07:55:00.000+02:00"/>
                    <xes:string key="sc:state" value="CheckFeasibility"/>
                    <xes:string key="concept:name" value="startCoding"/>
                    <xes:string key="sc:event" value="startCoding"/>
                    <xes:string key="sc:target" value="ImplementProduct"/>
                  </xes:event>
                  <xes:event>
                    <xes:date key="time:timestamp" value="2016-01-01T08:25:00.000+02:00"/>
                    <xes:string key="sc:state" value="ImplementProduct"/>
                    <xes:string key="concept:name" value="finishedCoding"/>
                    <xes:string key="sc:event" value="finishedCoding"/>
                    <xes:string key="sc:target" value="End1"/>
                  </xes:event>
                </xes:trace>
              </xes:log>
            </sc:data>
          </sc:datamodel>
          <sc:initial>
            <sc:transition target="ChooseProducts"/>
          </sc:initial>
          <sc:state id="ChooseProducts">
            <sc:transition event="collectInformation"/>
            <sc:transition event="startDeveloping" target="CheckFeasibility"/>
          </sc:state>
          <sc:state id="DevelopProducts">
            <sc:state id="CheckFeasibility">
              <sc:transition event="startCoding" target="ImplementProduct"/>
              <sc:transition event="abortDevelopment" target="End1"/>
            </sc:state>
            <sc:state id="ImplementProduct">
              <sc:transition event="finishedCoding" target="End1"/>
            </sc:state>
          </sc:state>
          <sc:state id="End1">
          </sc:state>
        </sc:scxml>
      </elements>
      <childLevel>
      </childLevel>
    </topLevel>
    <concretizations>
    </concretizations>
  </mba>
  </concretizations>
</mba>

let $mbaTactHouse :=
<mba xmlns="http://www.dke.jku.at/MBA" xmlns:sync="http://www.dke.jku.at/MBA/Synchronization" xmlns:sc="http://www.w3.org/2005/07/scxml" name="MyHouseholdInsuranceCompany" hierarchy="simple">
    <topLevel name="tacticalInsurance">
      <elements>
        <sc:scxml name="TacticalInsurance">
          <sc:datamodel>
            <sc:data id="_event"/>
            <sc:data id="_x">
              <db xmlns="">myMBAse</db>
              <collection xmlns="">MyInsuranceCompany</collection>
              <mba xmlns="">MyHouseholdInsuranceCompanyInsuranceCompany</mba>
              <currentStatus xmlns="">
                <state ref="End1"/>
              </currentStatus>
              <externalEventQueue xmlns=""/>
              <xes:log xmlns:xes="http://www.xes-standard.org/">
                <xes:trace>
                  <xes:event>
                    <xes:date key="time:timestamp" value="2016-01-01T07:30:00.000+02:00"/>
                    <xes:string key="sc:initial" value="TacticalInsurance"/>
                    <xes:string key="sc:target" value="ChooseProducts"/>
                  </xes:event>
                  <xes:event>
                    <xes:date key="time:timestamp" value="2016-01-01T07:37:00.000+02:00"/>
                    <xes:string key="sc:state" value="ChooseProducts"/>
                    <xes:string key="concept:name" value="collectInformation"/>
                    <xes:string key="sc:event" value="collectInformation"/>
                  </xes:event>
                  <xes:event>
                    <xes:date key="time:timestamp" value="2016-01-01T07:50:00.000+02:00"/>
                    <xes:string key="sc:state" value="ChooseProducts"/>
                    <xes:string key="concept:name" value="startDeveloping"/>
                    <xes:string key="sc:event" value="startDeveloping"/>
                    <xes:string key="sc:target" value="CheckFeasibility"/>
                  </xes:event>
                  <xes:event>
                    <xes:date key="time:timestamp" value="2016-01-01T07:55:00.000+02:00"/>
                    <xes:string key="sc:state" value="CheckFeasibility"/>
                    <xes:string key="concept:name" value="startCoding"/>
                    <xes:string key="sc:event" value="startCoding"/>
                    <xes:string key="sc:target" value="ImplementProduct"/>
                  </xes:event>
                  <xes:event>
                    <xes:date key="time:timestamp" value="2016-01-01T08:25:00.000+02:00"/>
                    <xes:string key="sc:state" value="ImplementProduct"/>
                    <xes:string key="concept:name" value="finishedCoding"/>
                    <xes:string key="sc:event" value="finishedCoding"/>
                    <xes:string key="sc:target" value="End1"/>
                  </xes:event>
                </xes:trace>
              </xes:log>
            </sc:data>
          </sc:datamodel>
          <sc:initial>
            <sc:transition target="ChooseProducts"/>
          </sc:initial>
          <sc:state id="ChooseProducts">
            <sc:transition event="collectInformation"/>
            <sc:transition event="startDeveloping" target="CheckFeasibility"/>
          </sc:state>
          <sc:state id="DevelopProducts">
            <sc:state id="CheckFeasibility">
              <sc:transition event="startCoding" target="ImplementProduct"/>
              <sc:transition event="abortDevelopment" target="End1"/>
            </sc:state>
            <sc:state id="ImplementProduct">
              <sc:transition event="finishedCoding" target="End1"/>
            </sc:state>
          </sc:state>
          <sc:state id="End1">
          </sc:state>
        </sc:scxml>
      </elements>
      <childLevel>
      </childLevel>
    </topLevel>
    <concretizations>
    </concretizations>
  </mba>
  
let $mbaTactCar :=
<mba xmlns="http://www.dke.jku.at/MBA" xmlns:sync="http://www.dke.jku.at/MBA/Synchronization" xmlns:sc="http://www.w3.org/2005/07/scxml" name="MyCarInsuranceCompany" hierarchy="simple">
    <topLevel name="tacticalInsurance">
      <elements>
        <sc:scxml name="TacticalInsurance">
          <sc:datamodel>
            <sc:data id="_event"/>
            <sc:data id="_x">
              <db xmlns="">myMBAse</db>
              <collection xmlns="">MyInsuranceCompany</collection>
              <mba xmlns="">MyCarInsuranceCompany</mba>
              <currentStatus xmlns="">
                <state ref="End1"/>
              </currentStatus>
              <externalEventQueue xmlns=""/>
              <xes:log xmlns:xes="http://www.xes-standard.org/">
                <xes:trace>
                  <xes:event>
                    <xes:date key="time:timestamp" value="2016-01-01T07:30:00.000+02:00"/>
                    <xes:string key="sc:initial" value="TacticalInsurance"/>
                    <xes:string key="sc:target" value="ChooseProducts"/>
                  </xes:event>
                  <xes:event>
                    <xes:date key="time:timestamp" value="2016-01-01T07:35:00.000+02:00"/>
                    <xes:string key="sc:state" value="ChooseProducts"/>
                    <xes:string key="concept:name" value="collectInformation"/>
                    <xes:string key="sc:event" value="collectInformation"/>
                  </xes:event>
                  <xes:event>
                    <xes:date key="time:timestamp" value="2016-01-01T07:40:00.000+02:00"/>
                    <xes:string key="sc:state" value="ChooseProducts"/>
                    <xes:string key="concept:name" value="startDeveloping"/>
                    <xes:string key="sc:event" value="startDeveloping"/>
                    <xes:string key="sc:target" value="CheckFeasibility"/>
                  </xes:event>
                  <xes:event>
                    <xes:date key="time:timestamp" value="2016-01-01T07:45:00.000+02:00"/>
                    <xes:string key="sc:state" value="CheckFeasibility"/>
                    <xes:string key="concept:name" value="startCoding"/>
                    <xes:string key="sc:event" value="startCoding"/>
                    <xes:string key="sc:target" value="ImplementProduct"/>
                  </xes:event>
                  <xes:event>
                    <xes:date key="time:timestamp" value="2016-01-01T07:55:00.000+02:00"/>
                    <xes:string key="sc:state" value="ImplementProduct"/>
                    <xes:string key="concept:name" value="finishedCoding"/>
                    <xes:string key="sc:event" value="finishedCoding"/>
                    <xes:string key="sc:target" value="End1"/>
                  </xes:event>
                </xes:trace>
              </xes:log>
            </sc:data>
          </sc:datamodel>
          <sc:initial>
            <sc:transition target="ChooseProducts"/>
          </sc:initial>
          <sc:state id="ChooseProducts">
            <sc:transition event="collectInformation"/>
            <sc:transition event="startDeveloping" target="CheckFeasibility"/>
          </sc:state>
          <sc:state id="DevelopProducts">
            <sc:state id="CheckFeasibility">
              <sc:transition event="startCoding" target="ImplementProduct"/>
              <sc:transition event="abortDevelopment" target="End1"/>
            </sc:state>
            <sc:state id="ImplementProduct">
              <sc:transition event="finishedCoding" target="End1"/>
            </sc:state>
          </sc:state>
          <sc:state id="End1">
          </sc:state>
        </sc:scxml>
      </elements>
      <childLevel>
      </childLevel>
    </topLevel>
    <concretizations>
    </concretizations>
  </mba>

return analysis:averageCycleTime($mba, "tacticalInsurance", "End1", "ChooseProducts") (:15M:)

(:return analysis:getStateLog($mbaTactHouse):)

(:return analysis:getCycleTimeOfInstance($mbaTactCar, "End1"):) (:40M:)

(:return analysis:getTotalActualCycleTime($mba, "tacticalInsurance", "End1"):)(:1H5M:)

(:return analysis:getTotalCycleTimeInStates($mbaTactCar, "tacticalInsurance", ("ChooseProducts", "CheckFeasibility")):) (:15M:)