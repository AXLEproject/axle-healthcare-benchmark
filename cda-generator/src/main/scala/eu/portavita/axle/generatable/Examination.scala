package eu.portavita.axle.generatable

import java.text.SimpleDateFormat
import java.util.Date

import scala.collection.JavaConversions.asScalaBuffer
import scala.collection.JavaConversions.bufferAsJavaList
import scala.collection.JavaConversions.mapAsJavaMap
import scala.collection.JavaConversions.mutableMapAsJavaMap
import scala.collection.JavaConversions.seqAsJavaList
import scala.collection.mutable
import scala.util.Random

import eu.portavita.concept.Act
import eu.portavita.concept.ActRelationShip
import eu.portavita.terminology.CodeSystem
import eu.portavita.terminology.HierarchyNode

/**
 * Represents an examination with underlying observations.
 *
 * @param code Act code of the examination.
 * @param observations Map of act codes onto observations.
 */
class Examination(val code: String, val observations: Map[String, Observation]) {

	// Guess the code system of the act code of this examination.
	lazy val codeSystem = CodeSystem.guess(code)

	// Start w/o a date for the prom (awww).
	var date: Option[Date] = None

	// Start with random id for observations.
	var lastId: Int = Random.nextInt

	/**
	 * Returns the next id for observations.
	 *
	 * @return
	 */
	def nextId: Int = {
		lastId += 1
		lastId
	}

	/**
	 * Sets the date of the examination.
	 *
	 * @param date
	 */
	def setDate(date: Date) = {
		this.date = Option(date)
	}

	/**
	 * Returns whether any observation in this examination has a value.
	 *
	 * @return
	 */
	lazy val hasValues: Boolean = observations.exists(elem => elem._2.hasValue)

	/**
	 * Returns the list of observations in this examination that have a non-empty value.
	 *
	 * @return.
	 */
	lazy val nonEmptyObservations = {
		observations.filter(elem => elem._2.hasValue).toList
	}

	/**
	 * Returns the map of the act codes onto Act objects for all non-empty observations
	 * in this examination.
	 *
	 * @return
	 */
	def getObservationActs: mutable.Map[String, Act] = {
		val acts = mutable.HashMap[String, Act]()
		for ((code, observation) <- observations) {
			val act = observation.toHl7Act
			if (act.isDefined) {
				act.get.id = nextId
				act.get.effectiveFromTime = new Date // TODO
				acts.put(code, act.get)
			}
		}
		acts
	}

	/**
	 * Builds the examination hierarchy, introducing organizers as required by the defined hierarchy.
	 *
	 * @param root Root node of the defined hierarchy.
	 *
	 * @return
	 */
	def buildHierarchy(root: HierarchyNode): eu.portavita.concept.Examination = {
		val resultActs = getObservationActs

		// Return as Java object.
		val exam = new eu.portavita.concept.Examination
		exam.actRelationships = mutable.Buffer[ActRelationShip]()

		/**
		 * Returns the act (observation or organizer) with the given code in this examination. If there
		 * is no such act, an organizer is added to the result set and returned.
		 *
		 * @param code Act code of the act.
		 *
		 * @return
		 */
		def getOrCreateAct(code: String): Act = {

			// Get existing act.
			val act = resultActs.get(code)
			if (act.isDefined) {
				return act.get
			}

			// No act found, create new organizer.
			val organizer = new Act
			organizer.id = nextId
			organizer.moodCode = "EVN"
			organizer.classCode = "ORGANIZER"
			organizer.code = code
			organizer.codeSystem = CodeSystem.guess(organizer.code)
			organizer.effectiveFromTime = new Date // TODO

			resultActs.put(code, organizer)

			organizer
		}

		/**
		 * Expands the given node in the hierarchy. If it must be displayed, an act is returned
		 * and a relationship with its parent is added. Otherwise None is returned.
		 *
		 * @param root Node in the hierarchy.
		 *
		 * @return
		 */
		def expand(root: HierarchyNode): Option[Act] = {
			for (component <- root.getComponents()) {
				val child = expand(component)
				if (child.isDefined) {
					val parent = getOrCreateAct(root.getCode())
					exam.actRelationships.add(new ActRelationShip(parent.id, child.get.id))
				}
			}
			resultActs.get(root.getCode())
		}

		// Expand the root hierarchy node.
		expand(root)

		// Store acts in examination
		exam.acts = resultActs.values.toList

		// Return as Java object.
		exam
	}

	override def toString() = {
		if (hasValues) {
			val s = StringBuilder.newBuilder
			s.append("Examination (code=" + code + ")")
			if (date.isDefined) {
				val formatter = new SimpleDateFormat("dd-MM-yyyy")
				s.append("on " + formatter.format(date.get))
			}
			s.append("\n")
			for ((code, observation) <- observations if observation.hasValue) {
				s.append("\t" + observation + "\n")
			}
			s.toString
		} else {
			"Examination for code " + code + ", which has no values"
		}
	}
}
