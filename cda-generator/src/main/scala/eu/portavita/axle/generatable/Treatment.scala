package eu.portavita.axle.generatable

import java.util.Arrays
import java.util.Date

import eu.portavita.axle.helper.RandomHelper
import eu.portavita.databus.data.model.PortavitaParticipation
import eu.portavita.databus.data.model.PortavitaTreatment
import eu.portavita.databus.data.model.PortavitaTreatmentOfExamination

class Treatment(
	val id: Long,
	val from: Date,
	val to: Date,
	val code: String,
	val completed: Boolean,
	val treatmentPlan: TreatmentPlan,
	val principalPractitioner: Practitioner) {

	def toPortavitaTreatment(subject: PortavitaParticipation, performer: PortavitaParticipation, author: PortavitaParticipation): PortavitaTreatment = {
		val treatment = new PortavitaTreatment()
		treatment.setActId(id)
		treatment.setClassCode("PCPR")
		treatment.setMoodCode("EVN")
		treatment.setCode(code)
		treatment.setFromTime(from)
		treatment.setToTime(to)
		treatment.setTreatmentPlanActId(treatmentPlan.id)
		treatment.setParticipants(Arrays.asList[PortavitaParticipation](subject, performer, author))
		if (completed) treatment.setStatusCode("completed") else treatment.setStatusCode("active")
		treatment.setTreatmentPlan(treatmentPlan.toPortavitaTreatmentPlan)
		treatment
	}

	def toPortavitaTreatmentOfExamination(examinationActId: Long): PortavitaTreatmentOfExamination = {
		val treatmentOfExamination = new PortavitaTreatmentOfExamination
		treatmentOfExamination.setTreatmentActId(id)
		treatmentOfExamination.setTreatmentCode(code)
		treatmentOfExamination.setExaminationActId(examinationActId)
		treatmentOfExamination
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
