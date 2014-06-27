package eu.portavita.axle.generatable

import java.util.ArrayList
import java.util.Date

import eu.portavita.databus.data.dto.ActDTO
import eu.portavita.databus.data.dto.ActRelationshipDTO
import eu.portavita.databus.data.dto.TreatmentPlanDTO

class TreatmentPlan(
		val id: Long,
		val code: String,
		val fromTime: Date,
		val toTime: Date,
		val completed: Boolean
		) {

	def toPortavitaTreatmentPlan: TreatmentPlanDTO = {
		val componentRelationships = new ArrayList[ActRelationshipDTO]()
		val componentDetails = new ArrayList[ActDTO]()
		val plan = new TreatmentPlanDTO(createMainAct, componentRelationships, componentDetails)
		plan
	}

	private def createMainAct: ActDTO = {
		val act = new ActDTO
		act.setId(id)
		act.setClassCode("PCPR")
		act.setMoodCode("INT")
		act.setStatusCode(if (completed) "completed" else "active")
		act.setNegationIndicator("N")
		act.setFromTime(fromTime)
		act.setToTime(toTime)
		act.setCode(code)
		act
	}
}

object TreatmentPlan {
	def sample(code: String, from: Date, to: Date, completed: Boolean): TreatmentPlan = {
		val id = ActId.next
		new TreatmentPlan(id, code, from, to, completed)
	}
}
