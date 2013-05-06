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
import eu.portavita.axle.model.PatientProfile
import scala.util.Random
import eu.portavita.axle.helper.DateTimes

class PatientGenerator (
	examinationGenerators: Map[String, ActorRef],
	patientProfile: PatientProfile
) extends Actor with ActorLogging {

	private val milisecondsPerDay = 1000 * 60 * 60 * 24

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
	 *
	 * @param organization
	 */
	private def generate (organization: Organization) = {
		val patient = Patient.sample(patientProfile, organization)

		val examinationsPerAge = patientProfile.sampleExaminations(patient)

		for {(age, examinations) <- examinationsPerAge
			(examinationCode, numberOfExaminations) <- examinations
			if examinationGenerators.contains(examinationCode)
			val Some(generator) = examinationGenerators.get(examinationCode)
		} {
			val randomDayInYear = Random.nextInt(365)
			val performedOn = DateTimes.getRelativeDate(randomDayInYear + age * 365, patient.birthDate)

			val timeCorrection = (Random.nextGaussian * milisecondsPerDay).toInt
			performedOn.setTime(performedOn.getTime() + timeCorrection)

			generator ! ExaminationRequest(patient, performedOn)
		}

	}
}