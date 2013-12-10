/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generators

import java.util.ArrayList
import java.util.Date
import java.util.List
import scala.collection.mutable
import eu.portavita.concept.CareProvision
import eu.portavita.concept.Examination
import eu.portavita.concept.Participant
import eu.portavita.dataProvider.IExaminationDataProvider
import eu.portavita.concept.Role
import scala.util.Random
import eu.portavita.axle.generatable.Practitioner

/**
 * Represents a queue of examination data. Data is appended to the queue and can be popped by an examination document
 * builder.
 */
class ExaminationDataProvider extends IExaminationDataProvider {

	val examinationQueue = mutable.Queue[Examination]()
	val patientQueue = mutable.Queue[CareProvision]()
	val participantQueue = mutable.Queue[List[Participant]]()

	var id = 0

	/**
	 * Appends an examination, patient and participants to the queue.
	 */
	def add(generatedExamination: eu.portavita.axle.generatable.Examination, hl7Examination: Examination) = {
		examinationQueue.enqueue(hl7Examination)
		patientQueue.enqueue(generatedExamination.patient.toHl7Patient)
		participantQueue.enqueue(createParticipants(generatedExamination))
		id = id + 1
		id
	}

	private def createParticipants(generatedExamination: eu.portavita.axle.generatable.Examination): ArrayList[Participant] = {
		val participants = new ArrayList[Participant]

		def createRole(practitioner: Practitioner): Role = {
			val participantRole = new Role
			// TODO: add role id!
			participantRole.playerId = practitioner.person.entityId.toString()
			participantRole.scoperId = practitioner.organizationEntityId.toString()
			participantRole
		}

		def createParticipant(typeCode: String, practitioner: Practitioner): Participant = {
			val participant = new Participant
			participant.fromDate = generatedExamination.date
			participant.typeCode = typeCode
			participant.role = createRole(practitioner)
			participant
		}

		participants.add(createParticipant("AUT", generatedExamination.practitioner))
		participants.add(createParticipant("ENT", generatedExamination.practitioner))
		participants.add(createParticipant("LA", generatedExamination.practitioner))
		participants.add(createParticipant("PRF", generatedExamination.practitioner))

		participants
	}

	/**
	 * Pops and returns the next examination from the queue.
	 *
	 * @return
	 */
	def get(examinationId: Int): Examination = {
		examinationQueue.dequeue
	}

	/**
	 * Pops and returns the next set of authors from the queue.
	 *
	 * @return
	 */
	def getParticipants(actId: Int): List[Participant] = {
		val list = new ArrayList[Participant]
		list.addAll(participantQueue.dequeue)
		list
	}

	/**
	 * Pops and returns the next patient from the queue.
	 *
	 * @return
	 */
	def getCareProvisions(actId: Int): List[CareProvision] = {
		val list = new ArrayList[CareProvision]()
		list.add(patientQueue.dequeue)
		list
	}
}
