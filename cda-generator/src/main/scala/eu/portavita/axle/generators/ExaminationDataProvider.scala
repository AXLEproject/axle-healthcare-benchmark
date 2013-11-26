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

/**
 * Represents a queue of examination data. Data is appended to the queue and can be popped by an examination document
 * builder.
 */
class ExaminationDataProvider extends IExaminationDataProvider {

	// Create queue of examinations.
	val examinationQueue = mutable.Queue[Examination]()

	// Create queue of patients.
	val patientQueue = mutable.Queue[CareProvision]()
	var id = 0

	// Create queue of participant lists.
	val participantQueue = mutable.Queue[List[Participant]]()

	/**
	 * Appends an examination to the queue.
	 *
	 * @param patient Patient of the examination.
	 * @param examination Examination data.
	 */
	def add(patient: eu.portavita.axle.generatable.Patient, examination: Examination) = {
		examinationQueue.enqueue(examination)
		patientQueue.enqueue(patient.toHl7Patient)
		val participants = new ArrayList[Participant]
		def createParticipant(typeCode : String) : Participant = {
			val participant = new Participant
			participant.fromDate = new Date
			participant.typeCode = typeCode
			val participantRole = new Role
			participantRole.playerId = Random.nextInt.toString
			participantRole.scoperId = patient.organization.id.toString
			participant.role = participantRole
			participant
		}
		participants.add(createParticipant("AUT"))
		participants.add(createParticipant("ENT"))
		participants.add(createParticipant("LA"))
		participants.add(createParticipant("PRF"))
		participantQueue.enqueue(participants)
		id = id + 1
		id
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
