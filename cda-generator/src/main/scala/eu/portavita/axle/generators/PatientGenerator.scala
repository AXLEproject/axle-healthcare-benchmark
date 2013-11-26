/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generators

import java.io.File

import scala.util.Random

import akka.actor.Actor
import akka.actor.ActorLogging
import akka.actor.ActorRef
import akka.actor.actorRef2Scala
import eu.portavita.axle.GeneratorConfig
import eu.portavita.axle.generatable.Organization
import eu.portavita.axle.generatable.Patient
import eu.portavita.axle.helper.DateTimes
import eu.portavita.axle.helper.FilesWriter
import eu.portavita.axle.messages.ExaminationRequest
import eu.portavita.axle.messages.PatientRequest
import eu.portavita.axle.model.PatientProfile
import eu.portavita.databus.messagebuilder.JaxbHelper
import eu.portavita.databus.messagebuilder.builders.PatientBuilder

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
		store(patient)

		val examinationsPerAge = patientProfile.sampleExaminations(patient)

		for {(age, examinations) <- examinationsPerAge
			(examinationCode, numberOfExaminations) <- examinations
			if examinationGenerators.contains(examinationCode)
			val Some(generator) = examinationGenerators.get(examinationCode)
		} {
			val randomDayInYear = Random.nextInt(365)
			val performedOn = DateTimes.getRelativeDate(randomDayInYear + age * 365, patient.person.birthDate)

			val timeCorrection = (Random.nextGaussian * milisecondsPerDay).toInt
			performedOn.setTime(performedOn.getTime() + timeCorrection)

			generator ! ExaminationRequest(patient, performedOn)
		}
	}

	private def store(patient: Patient) {
		val directoryPath = GeneratorConfig.outputDirectory + patient.organization.directoryName + File.separator + "patients"
		val builder = new PatientBuilder
		builder.setMessageInput(patient.toPortavitaPatient)
		builder.build()
		val document = JaxbHelper.marshal(builder.getMessageContent())
		val fileName = "patient-" + patient.roleId + ".xml"
		FilesWriter.write(directoryPath, fileName, document)
	}
}
