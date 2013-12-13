/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generatable

import java.text.SimpleDateFormat
import java.util.Date
import scala.collection.JavaConversions.asScalaBuffer
import scala.collection.JavaConversions.bufferAsJavaList
import scala.collection.JavaConversions.mapAsJavaMap
import scala.collection.JavaConversions.mutableMapAsJavaMap
import scala.collection.JavaConversions.seqAsJavaList
import scala.collection.mutable
import eu.portavita.terminology.CodeSystem
import eu.portavita.terminology.HierarchyNode
import java.util.ArrayList
import eu.portavita.databus.data.model.PortavitaTreatmentOfExamination
import eu.portavita.databus.data.model.PortavitaExamination
import eu.portavita.databus.data.model.PortavitaParticipation
import eu.portavita.databus.data.model.PortavitaActRelationship
import eu.portavita.databus.data.model.PortavitaAct

/**
 * Represents an examination with underlying observations.
 *
 * @param code Act code of the examination.
 * @param observations Map of act codes onto observations.
 */
class Examination(
	val patient: Patient,
	val code: String,
	val date: Date,
	val observations: Map[String, Observation],
	val practitioner: Practitioner) {

	/** Code system of act code. */
	lazy val codeSystem = CodeSystem.guess(code)

	/**
	 * Returns whether any observation in this examination has a value.
	 *
	 * @return whether any observation in this examination has a value
	 */
	lazy val hasValues: Boolean = observations.exists(elem => elem._2.hasValue)

	/**
	 * Returns the list of observations in this examination that have a non-empty value.
	 *
	 * @return non-empty observations
	 */
	lazy val nonEmptyObservations = observations.filter(elem => elem._2.hasValue).toList

	/**
	 * Returns the map of the act codes onto Act objects for all non-empty observations
	 * in this examination.
	 *
	 * @return map of the act codes onto Act objects
	 */
	def getPortavitaObservationActs: mutable.Map[String, PortavitaAct] = {
		val acts = mutable.Map.empty[String, PortavitaAct]
		for {
			(code, observation) <- observations
			act <- observation.toHl7Act(date)
		} yield {
			acts.put(code, act)
		}
		acts
	}

	def build(root: HierarchyNode): PortavitaExamination = {
		val actDetails = getPortavitaObservationActs
		val actRelationships = mutable.ListBuffer.empty[PortavitaActRelationship]

		/**
		 * Expands the given node in the hierarchy. If it must be displayed, an act is returned
		 * and a relationship with its parent is added. Otherwise None is returned.
		 *
		 * @param root Node in the hierarchy.
		 *
		 * @return
		 */
		def expand(root: HierarchyNode): Option[PortavitaAct] = {
			for (component <- root.getComponents()) {
				val child = expand(component)
				if (child.isDefined) {
					val parent = actDetails.getOrElseUpdate(root.getCode(), createOrganizer(code, date))
					actRelationships.add(createComponentActRelationship(parent.getId(), child.get.getId()))
				}
			}
			actDetails.get(root.getCode())
		}

		expand(root)

		val examAct = actDetails.get(code).get
		val participants = createParticipants(examAct.getId())
		val treatments = createTreatments(examAct.getId())

		new PortavitaExamination(examAct, actRelationships, actDetails.values.toList, participants, treatments)
	}

	def createTreatments(examinationActId: Long): ArrayList[PortavitaTreatmentOfExamination] = {
		val treatments = new ArrayList[PortavitaTreatmentOfExamination]()
		for (treatment <- patient.treatments) {
			treatments.add(treatment.toPortavitaTreatmentOfExamination(examinationActId))
		}
		treatments
	}

	def createOrganizer(code: String, date: Date): PortavitaAct = {
		val organizer = new PortavitaAct
		organizer.setId(ActId.next)
		organizer.setMoodCode("EVN")
		organizer.setClassCode("ORGANIZER")
		organizer.setCode(code)
		organizer.setFromTime(date)
		organizer.setStatusCode("completed")
		organizer
	}

	def createComponentActRelationship(source: Long, target: Long): PortavitaActRelationship = {
		val relationship = new PortavitaActRelationship
		relationship.setSourceId(source)
		relationship.setTargetId(target)
		relationship.setTypeCode("COMP")
		relationship.setSequence(1)
		relationship.setContextConductionIndicator("Y")
		relationship.setContextControlCode("AN")
		relationship
	}

	private def createParticipants(id: Long): ArrayList[PortavitaParticipation] = {
		val participants = new ArrayList[PortavitaParticipation]

		def createParticipant(typeCode: String, roleId: Long): PortavitaParticipation = {
			val participant = new PortavitaParticipation
			participant.setActId(id)
			participant.setFromTime(date)
			participant.setTypeCode(typeCode)
			participant.setRoleId(roleId)
			participant
		}

		participants.add(createParticipant("AUT", practitioner.roleId))
		participants.add(createParticipant("ENT", practitioner.roleId))
		participants.add(createParticipant("LA", practitioner.roleId))
		participants.add(createParticipant("PRF", practitioner.roleId))
		participants.add(createParticipant("SBJ", patient.roleId))

		participants
	}

	override def toString() = {
		if (hasValues) {
			val s = StringBuilder.newBuilder
			s.append("Examination (code=" + code + ")")
			val formatter = new SimpleDateFormat("dd-MM-yyyy")
			s.append("on " + formatter.format(date))
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
