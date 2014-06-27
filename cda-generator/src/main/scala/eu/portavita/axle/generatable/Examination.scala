/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generatable

import java.util.ArrayList
import java.util.Date

import scala.collection.JavaConversions.asScalaBuffer
import scala.collection.JavaConversions.bufferAsJavaList
import scala.collection.JavaConversions.mapAsJavaMap
import scala.collection.JavaConversions.mutableMapAsJavaMap
import scala.collection.JavaConversions.seqAsJavaList
import scala.collection.mutable

import eu.portavita.axle.helper.CdaValueBuilderHelper
import eu.portavita.axle.helper.CodeSystemProvider
import eu.portavita.axle.helper.DateTimes
import eu.portavita.databus.data.dto.ActDTO
import eu.portavita.databus.data.dto.ActRelationshipDTO
import eu.portavita.databus.data.dto.ExaminationDTO
import eu.portavita.databus.data.dto.ParticipationDTO
import eu.portavita.databus.data.dto.TreatmentOfExaminationDTO
import eu.portavita.terminology.CodeSystem
import eu.portavita.terminology.HierarchyNode

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
	lazy val codeSystem = CodeSystemProvider.get(code)

	lazy val displayNameProvider = CdaValueBuilderHelper.getDisplayNameProvider

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
	def getPortavitaObservationActs: mutable.Map[String, ActDTO] = {
		val acts = mutable.Map.empty[String, ActDTO]
		for {
			(code, observation) <- observations
			act <- observation.toHl7Act(date)
		} yield {
			acts.put(code, act)
		}
		acts
	}

	def build(root: HierarchyNode): ExaminationDTO = {
		val actDetails = getPortavitaObservationActs
		val actRelationships = mutable.ListBuffer.empty[ActRelationshipDTO]

		/**
		 * Expands the given node in the hierarchy. If it must be displayed, an act is returned
		 * and a relationship with its parent is added. Otherwise None is returned.
		 *
		 * @param root Node in the hierarchy.
		 *
		 * @return
		 */
		def expand(root: HierarchyNode): Option[ActDTO] = {
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

		new ExaminationDTO(examAct, actRelationships, actDetails.values.toList, participants, treatments)
	}

	def generateText(): String = {
		val sb = new StringBuilder
		sb.append("This is the report about %s examination that was performed on date %s by %s\n".format(displayNameProvider.get(code), DateTimes.dateFormat.format(date), practitioner.toReportString))
		sb.append("The examination was performed on patient %s\n".format(patient.toString()))
		sb.append("In this examination, the following %d observations were made:\n".format(observations.size))
		for((key, observation) <- observations) sb.append(" - %s\n".format(observation.toReportString(displayNameProvider)))
		sb.toString()
	}

	def createTreatments(examinationActId: Long): ArrayList[TreatmentOfExaminationDTO] = {
		val treatments = new ArrayList[TreatmentOfExaminationDTO]()
		for (treatment <- patient.treatments) {
			treatments.add(treatment.toPortavitaTreatmentOfExamination(examinationActId))
		}
		treatments
	}

	def createOrganizer(code: String, date: Date): ActDTO = {
		val organizer = new ActDTO
		organizer.setId(ActId.next)
		organizer.setMoodCode("EVN")
		organizer.setClassCode("ORGANIZER")
		organizer.setCode(code)
		organizer.setFromTime(date)
		organizer.setStatusCode("completed")
		organizer
	}

	def createComponentActRelationship(source: Long, target: Long): ActRelationshipDTO = {
		val relationship = new ActRelationshipDTO
		relationship.setSourceId(source)
		relationship.setTargetId(target)
		relationship.setTypeCode("COMP")
		relationship.setSequence(1)
		relationship.setContextConductionIndicator("Y")
		relationship.setContextControlCode("AN")
		relationship
	}

	private def createParticipants(id: Long): ArrayList[ParticipationDTO] = {
		val participants = new ArrayList[ParticipationDTO]

		def createParticipant(typeCode: String, roleId: Long): ParticipationDTO = {
			val participant = new ParticipationDTO
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
			s.append("on " + DateTimes.dateFormat.format(date))
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
