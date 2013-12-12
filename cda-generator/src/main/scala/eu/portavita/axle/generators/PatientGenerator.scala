/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generators

import scala.util.Random

import akka.actor.Actor
import akka.actor.ActorLogging
import akka.actor.ActorRef
import akka.actor.actorRef2Scala
import eu.portavita.axle.Generator
import eu.portavita.axle.generatable.Organization
import eu.portavita.axle.generatable.Organization
import eu.portavita.axle.generatable.Patient
import eu.portavita.axle.generatable.Patient
import eu.portavita.axle.generatable.Treatment
import eu.portavita.axle.helper.DateTimes
import eu.portavita.axle.helper.DateTimes
import eu.portavita.axle.helper.MarshalHelper
import eu.portavita.axle.messages.ExaminationRequest
import eu.portavita.axle.messages.PatientRequest
import eu.portavita.axle.model.PatientProfile
import eu.portavita.axle.publisher.RabbitMessageQueue
import eu.portavita.databus.messagebuilder.builders.PatientBuilder
import eu.portavita.databus.messagebuilder.builders.TreatmentBuilder

class PatientGenerator (
	examinationGenerators: Map[String, ActorRef],
	patientProfile: PatientProfile
) extends Actor with ActorLogging {

	private val milisecondsPerDay = 1000 * 60 * 60 * 24
	private val publisher = new RabbitMessageQueue

	private val marshaller = Generator.fhirJaxbContext.createMarshaller()

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
		publish(patient)

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

	private def publish(patient: Patient) {
		publisher.publish(marshalPatient(patient), "source.generator.type.fhir.patient.insert")
		for (treatment <- patient.treatments) {
			publisher.publish(marshalTreatment(treatment, patient), "source.generator.type.hl7v3.treatment.insert")
		}
	}

	private def marshalPatient(patient: Patient): String = {
		val builder = new PatientBuilder
		builder.setMessageInput(patient.toPortavitaPatient)
		builder.build()
		MarshalHelper.marshal(builder.getMessageContent(), marshaller)
	}

	private def marshalTreatment(treatment: Treatment, subject: Patient): String = {
		val builder = new TreatmentBuilder
		val subjectParticipation = subject.toParticipation(treatment.id, treatment.from, treatment.to)
		val performerParticipation = treatment.principalPractitioner.toParticipation(treatment.id, treatment.from, treatment.to)
		val authorParticipation = treatment.principalPractitioner.toParticipation(treatment.id, treatment.from, treatment.to, typeCode = "AUT")
		val portavitaTreatment = treatment.toPortavitaTreatment(subjectParticipation, performerParticipation, authorParticipation)
		builder.setMessageInput(portavitaTreatment)
		builder.build()
		MarshalHelper.marshal(builder.getMessageContent(), marshaller)
	}
}
