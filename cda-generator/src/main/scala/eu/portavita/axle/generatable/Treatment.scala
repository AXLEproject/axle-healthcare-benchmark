package eu.portavita.axle.generatable

import java.util.Arrays
import java.util.Date

import eu.portavita.axle.helper.RandomHelper
import eu.portavita.databus.CodeSystem
import eu.portavita.databus.data.dto.ActDTO
import eu.portavita.databus.data.dto.ActRelationshipDTO
import eu.portavita.databus.data.dto.ParticipationDTO
import eu.portavita.databus.data.dto.TreatmentDTO
import eu.portavita.databus.data.dto.TreatmentOfExaminationDTO

class Treatment(
	val id: Long,
	val from: Date,
	val to: Date,
	val code: String,
	val completed: Boolean,
	val treatmentPlan: TreatmentPlan,
	val principalPractitioner: Practitioner) {

	def toPortavitaTreatment(subject: ParticipationDTO, performer: ParticipationDTO, author: ParticipationDTO): TreatmentDTO = {
		val treatmentAct = toTreatmentAct
		val actRelationships = Arrays.asList[ActRelationshipDTO]()
		val actDetails = Arrays.asList[ActDTO]()
		val participants = Arrays.asList[ParticipationDTO](subject, performer, author)
		val treatment = new TreatmentDTO(treatmentAct, actRelationships, actDetails, participants)
		treatment.setTreatmentPlanActId(treatmentPlan.id)
		treatment.setTreatmentPlan(treatmentPlan.toPortavitaTreatmentPlan)
		treatment
	}

	def toTreatmentAct: ActDTO = {
		val act = new ActDTO
		act.setId(id)
		act.setClassCode("PCPR")
		act.setMoodCode("EVN")
		act.setNegationIndicator("N")
		act.setCode(code)
		act.setCodeSystemOid(CodeSystem.guess(code).getOid())
		act.setFromTime(from)
		act.setToTime(to)
		act.setStatusCode(if (completed) "completed" else "active")
		act
	}

	def toPortavitaTreatmentOfExamination(examinationActId: Long): TreatmentOfExaminationDTO = {
		val treatmentOfExamination = new TreatmentOfExaminationDTO
		treatmentOfExamination.setTreatmentActId(id)
		treatmentOfExamination.setTreatmentCode(code)
		treatmentOfExamination.setExaminationActId(examinationActId)
		treatmentOfExamination
	}

	override def toString = {
		"treatment from %s".format(principalPractitioner.person.toString())
	}
}

object Treatment {
	val treatmentCodes = List("170742000", "COPD", "CVRM")

	def sample(from: Date, to: Date = null, principalPractitioner: Practitioner): Treatment = {
		val id = ActId.next
		val code = RandomHelper.randomElement(treatmentCodes)
		val completed = false
		val treatmentPlan = TreatmentPlan.sample(code, from, to, completed)
		new Treatment(id, from, to, code, completed, treatmentPlan, principalPractitioner)
	}
}
