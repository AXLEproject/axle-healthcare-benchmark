package eu.portavita.axle.generatable

import java.util.Date
import eu.portavita.axle.helper.DateTimes
import eu.portavita.axle.helper.RandomHelper
import eu.portavita.databus.data.model.PortavitaTreatment
import eu.portavita.databus.data.model.Participation
import java.util.Arrays

class Treatment(
		val id: Long,
		val from: Date,
		val to: Date,
		val code: String,
		val completed: Boolean,
		val treatmentPlan: TreatmentPlan,
		val principalPractitioner: Practitioner
		) {

	def toPortavitaTreatment(subject: Participation, performer: Participation, author: Participation): PortavitaTreatment = {
		val t = new PortavitaTreatment()
		t.setActId(id)
		t.setClassCode("PCPR")
		t.setMoodCode("EVN")
		t.setCode(code)
		t.setFromTime(from)
		t.setToTime(to)
		t.setCarePlanActId(treatmentPlan.id)
		t.setParticipants(Arrays.asList[Participation](subject, performer, author))
		if (completed) t.setStatusCode("completed") else t.setStatusCode("active")
		t
	}
}

object Treatment {
	val treatmentCodes = List("170742000", "COPD", "CVRM")

	def sample(from: Date, to: Date = null, principalPractitioner: Practitioner): Treatment = {
		val id = ActId.next
		val code = RandomHelper.randomElement(treatmentCodes)
		val completed = false
		val treatmentPlan = TreatmentPlan.sample
		new Treatment(id, from, to, code, completed, treatmentPlan, principalPractitioner)
	}
}
