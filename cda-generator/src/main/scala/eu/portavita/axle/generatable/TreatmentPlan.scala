package eu.portavita.axle.generatable

class TreatmentPlan(
		val id: Long
		) {

}

object TreatmentPlan {
	def sample: TreatmentPlan = {
		val id = ActId.next
		new TreatmentPlan(id)
	}
}
