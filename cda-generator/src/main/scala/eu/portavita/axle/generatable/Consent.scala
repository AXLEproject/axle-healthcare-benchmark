package eu.portavita.axle.generatable

import eu.portavita.databus.data.dto.ConsentDocumentDTO
import eu.portavita.databus.data.dto.ActDTO
import eu.portavita.databus.data.dto.ActRelationshipDTO
import scala.collection.mutable.ListBuffer
import java.util.Arrays.ArrayList
import java.util.ArrayList
import java.util.Arrays
import eu.portavita.databus.data.dto.ParticipationDTO
import eu.portavita.databus.data.dto.TemplateIdDTO
import java.util.Date
import eu.portavita.axle.helper.ParticipationHelper
import eu.portavita.axle.helper.RandomHelper
import eu.portavita.databus.IdRoot

class Consent(patient: Patient, 
  date: Date, 
  treatmentForConsent: Treatment, 
  custodian: Organization, 
  enteringPractitioner: Practitioner, 
  receivingProvider: Practitioner, 
  optOut: Boolean) {

  def toConsentDTO: ConsentDocumentDTO = {
    val consentDirective = createConsentDirective()
    val observationAction = createObservationAction()
    val observationRelatedProblem = createObservationRelatedProblem()

    val actRelationships: ArrayList[ActRelationshipDTO] = new ArrayList[ActRelationshipDTO]()
    val templateIdAction = new TemplateIdDTO("2.16.840.1.113883.3.445.8");
    actRelationships.add(relate(consentDirective, observationAction, "COMP", templateIdAction));
    actRelationships.add(relate(consentDirective, observationRelatedProblem, "COMP", null))

    val participants: ArrayList[ParticipationDTO] = createParticipants(consentDirective.getId)
    participants.add(createReceivingProvider(consentDirective.getId))

    new ConsentDocumentDTO(consentDirective, actRelationships, Arrays.asList(observationAction, observationRelatedProblem), participants)
  }

  def relate(source: ActDTO, target: ActDTO, typeCode: String, templateId: TemplateIdDTO): ActRelationshipDTO = {
    val relationship = new ActRelationshipDTO
    relationship.setSourceId(source.getId)
    relationship.setTargetId(target.getId)
    relationship.setTypeCode(typeCode)
    relationship.setSequence(1)
    relationship.setContextConductionIndicator("Y")
    relationship.setContextControlCode("AN")
    if (templateId != null) relationship.setTemplateId(templateId)
    relationship
  }

  // Purpose of use: Research
  def createConsentDirective(): ActDTO = {
    val act = new ActDTO
    act.setId(ActId.next)
    act.setCode("HRESCH") 
    act.setCodeSystemOid("2.16.840.1.113883.3.18.7.1")
    act.setClassCode("ACT")
    act.setMoodCode("DEF")
    act.setFromTime(date)
    act.setStatusCode("ACTIVE")
    act.getTemplateId().add(new TemplateIdDTO("2.16.840.1.113883.3.445.5"));
    act
  }

  // Action  
  def createObservationAction(): ActDTO = {
    val act = new ActDTO
    act.setId(ActId.next)
    act.setCode("IDISCL")
    act.setCodeSystemOid("2.16.840.1.113883.5.4")
    act.setNegationIndicator(if (optOut) "N" else "Y")
    act.setClassCode("OBS")
    act.setMoodCode("DEF")
    act.setFromTime(date)
    act.setStatusCode("COMPLETED")
    act
  }

  // Related Problem
  def createObservationRelatedProblem(): ActDTO = {
    val act = new ActDTO
    act.setId(ActId.next)
    act.setCode("8319008")
    act.setClassCode("OBS")
    act.setMoodCode("DEF")
    act.setValue(treatmentForConsent.code) 
    act.setFromTime(date)
    act.getTemplateId().add(new TemplateIdDTO("2.16.840.1.113883.3.445.11"))
    act.getTemplateId().add(new TemplateIdDTO("2.16.840.1.113883.10.20.22.4.4"))
    act.setStatusCode("COMPLETED")
    act
  }

  private def createParticipants(actId: Long): ArrayList[ParticipationDTO] = {
    def createParticipant(typeCode: String, roleId: Long): ParticipationDTO = {
      ParticipationHelper.createParticipant(actId, date, typeCode, roleId)
    }

    val participants = new ArrayList[ParticipationDTO]
    participants.add(createParticipant("AUT", enteringPractitioner.roleId))
    participants.add(createParticipant("ENT", enteringPractitioner.roleId))
    participants.add(createParticipant("LA", enteringPractitioner.roleId))
    participants.add(createParticipant("PRF", enteringPractitioner.roleId))
    participants.add(createParticipant("SBJ", patient.roleId))
    participants
  }

  def createReceivingProvider(actId: Long): ParticipationDTO = {
    def createParticipant(typeCode: String, roleId: Long): ParticipationDTO = {
      ParticipationHelper.createParticipant(actId, date, typeCode, roleId)
    }
    
    val receivingProvider = createParticipant("IRCP", enteringPractitioner.roleId)
    receivingProvider
  }

}

object Consent {
  def sample(patient: Patient,
    custodian: Organization): Consent = {
    val treatment = RandomHelper.randomElement(patient.treatments) // TODO take random element, or generate a consent for each treatment
    val consentStartDate = treatment.from
    val optOut: Boolean = RandomHelper.coinFlip
    val receiver = treatment.principalPractitioner
    val enterer = treatment.principalPractitioner
    new Consent(patient, consentStartDate, treatment, custodian, enterer, receiver, optOut)
  }
}
