package eu.portavita.axle.generatable

import eu.portavita.databus.data.model.PortavitaTreatmentPlan
import eu.portavita.databus.data.model.PortavitaAct
import java.util.ArrayList
import eu.portavita.databus.data.model.PortavitaActRelationship
import java.util.Date

class TreatmentPlan(
		val id: Long,
		val code: String,
		val fromTime: Date,
		val toTime: Date,
		val completed: Boolean
		) {

	def toPortavitaTreatmentPlan: PortavitaTreatmentPlan = {
		val componentRelationships = new ArrayList[PortavitaActRelationship]()
		val componentDetails = new ArrayList[PortavitaAct]()
		val plan = new PortavitaTreatmentPlan(createMainAct, componentRelationships, componentDetails)
		plan
	}

	private def createMainAct: PortavitaAct = {
		val act = new PortavitaAct
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
