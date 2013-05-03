/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generators

import akka.actor.Actor
import akka.actor.ActorLogging
import akka.actor.ActorRef
import akka.actor.actorRef2Scala
import eu.portavita.axle.Generator
import eu.portavita.axle.generatable.Organization
import eu.portavita.axle.generatable.Patient
import eu.portavita.axle.messages.ExaminationRequest
import eu.portavita.axle.messages.PatientRequest

class PatientGenerator (
	examinationGenerators: List[ActorRef]
) extends Actor with ActorLogging {

	def receive = {
		case PatientRequest(organization) =>
			generate(organization)

		case x =>
			log.warning("Received message that I cannot handle: " + x.toString)
	}

	/**
	 * Generates a random patient, sends the patient to the output actor,
	 * and then generates examinations for that patient, which are also
	 * sent to the output actor.
	 */
	private def generate (organization: Organization) = {
		val patient = Patient.sample(organization)

		val nrOfExaminations = Generator.config.getInt("nrOfExaminations")

		// Generate observations for patient
		generateObservations(patient, nrOfExaminations)
	}

	/**
	 * Generates the given number of examinations for the given patient
	 * and sends them to the output actor.
	 */
	private def generateObservations (patient: Patient, nrOfExaminations: Int): Unit = {
		for (i <- 1 to nrOfExaminations;
			examinationGeneratorActor <- examinationGenerators
		) {
			examinationGeneratorActor ! ExaminationRequest(patient)
		}
	}

}