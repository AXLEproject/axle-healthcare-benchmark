/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generators

import java.util.ArrayList
import java.util.Date
import java.util.List

import scala.collection.mutable

import eu.portavita.concept.Author
import eu.portavita.concept.Examination
import eu.portavita.concept.Patient
import eu.portavita.dataProvider.IExaminationDataProvider

/**
 * Represents a queue of examination data. Data is appended to the queue and can be popped by an examination document
 * builder.
 */
class ExaminationDataProvider extends IExaminationDataProvider {

	// Create queue of examinations.
	val examinationQueue = mutable.Queue[Examination]()

	// Create queue of patients.
	val patientQueue = mutable.Queue[Patient]()
	var id = 0

	/**
	 * Appends an examination to the queue.
	 *
	 * @param patient Patient of the examination.
	 * @param examination Examination data.
	 */
	def add(
		patient: eu.portavita.axle.generatable.Patient,
		examination: Examination) = {
		examinationQueue.enqueue(examination)
		patientQueue.enqueue(patient.toHl7Patient)
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
	def getAuthors(actId: Int, typeCode: String): List[Author] = {
		val list = new ArrayList[Author]
		val author = new Author()
		author.entityId = "123456"
		author.fromDate = new Date
		list.add(author)
		list
	}

	/**
	 * Pops and returns the next patient from the queue.
	 *
	 * @return
	 */
	def getPatients(actId: Int): List[Patient] = {
		val list = new ArrayList[Patient]()
		list.add(patientQueue.dequeue)
		list
	}
}
