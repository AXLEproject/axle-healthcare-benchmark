/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generators

import java.util.Date

import scala.collection.immutable.Map
import scala.collection.mutable.HashMap
import scala.util.Random

import akka.actor.Actor
import akka.actor.ActorLogging
import akka.actor.ActorRef
import akka.actor.actorRef2Scala
import eu.portavita.axle.GeneratorConfig
import eu.portavita.axle.generatable.Organization
import eu.portavita.axle.generatable.Patient
import eu.portavita.axle.generatable.Treatment
import eu.portavita.axle.helper.CdaValueBuilderHelper
import eu.portavita.axle.helper.DateTimes
import eu.portavita.axle.helper.MarshalHelper
import eu.portavita.axle.model.PatientProfile
import eu.portavita.axle.publisher.PublishHelper
import eu.portavita.axle.publisher.RabbitMessageQueue
import eu.portavita.databus.messagebuilder.builders.PatientBuilder
import eu.portavita.databus.messagebuilder.builders.TreatmentBuilder
import javax.xml.bind.Marshaller

sealed trait PatientMessage
case class PatientRequest(val organization: Organization) extends PatientMessage

class PatientGenerator(
	examinationGenerators: Map[String, ActorRef],
	patientProfile: PatientProfile) extends Actor with ActorLogging {

	private val milisecondsPerDay = 1000 * 60 * 60 * 24
	private val publisher = new PublishHelper(context.actorSelection("/user/publisher"))
  lazy private val consentGeneratorActor = context.actorSelection("/user/consentGenerator")

	private val queue = new PatientPublisher

	def receive = {
		case request @ PatientRequest(organization) =>
			InPipeline.waitGeneratingPatients
			for (i <- 1 to organization.nrOfPatients) {
				generate(organization)
			}
			val inPipeline = InPipeline.patientRequests.finishRequest
//			if (inPipeline % 100 == 0) log.info("Just finished one, now %d patient requests in pipeline".format(inPipeline))

		case x =>
			log.warning("Received message that I cannot handle: " + x.toString)
	}

	/**
	 * Generates a random patient, publishes the patient,
	 * and then sends requests to generate examinations for that patient.
	 *
	 * @param organization
	 */
	private def generate(organization: Organization) = {
		val patient = Patient.sample(patientProfile, organization)
		queue.publish(patient)
    consentGeneratorActor ! ConsentGenerationRequest(patient)
		generateExaminations(patient)
	}

	private def generateExaminations(patient: Patient) {
		for ((examinationCode, performanceDates) <- generatePerformanceDatesPerExamination(patient)) {
			if (examinationGenerators.contains(examinationCode)) {
				//				log.error("LUCKILY, there was a generator for %s!!!".format(examinationCode))
				examinationGenerators.get(examinationCode).get ! ExaminationGenerationRequest(patient, performanceDates)
				InPipeline.examinationRequests.newRequest
			} else {
				//				log.error("There was no generator for %s!!!".format(examinationCode))
			}
		}
	}

	private def generatePerformanceDatesPerExamination(patient: Patient): HashMap[String, IndexedSeq[Date]] = {
		val toBeGenerated = new HashMap[String, IndexedSeq[Date]]

		val examinationsPerAge = patientProfile.sampleExaminations(patient)
		for {
			(age, examinations) <- examinationsPerAge
			(examinationCode, numberOfExaminations) <- examinations
		} {
			val performanceDates = generatePerformanceDates(numberOfExaminations, age, patient)
			toBeGenerated.get(examinationCode) match {
				case Some(list) => toBeGenerated.put(examinationCode, list ++ performanceDates)
				case None => toBeGenerated.put(examinationCode, performanceDates)
			}
		}

		toBeGenerated
	}

	private def generatePerformanceDates(nrOfExaminations: Int, age: Int, patient: Patient): IndexedSeq[Date] = {
                var amount = nrOfExaminations / GeneratorConfig.patientsPerOrganizationRatio
                if (amount > 0) {
                        	log.info(s"Generating $nrOfExaminations / ${GeneratorConfig.patientsPerOrganizationRatio} = $amount examinations")
                }
		for (i <- 0 to amount) yield {
			generatePerformanceDate(age, patient)
		}
	}

	private def generatePerformanceDate(age: Int, patient: Patient): Date = {
		val randomDayInYear = Random.nextInt(365)
		val performedOn = DateTimes.getRelativeDate(randomDayInYear + age * 365, patient.person.birthDate)
		val timeCorrection = (Random.nextGaussian * milisecondsPerDay).toInt
		performedOn.setTime(performedOn.getTime() + timeCorrection)
		performedOn
	}

	class PatientPublisher {
		private val fhirMarshaller = GeneratorConfig.fhirJaxbContext.createMarshaller()
		private val cdaMarshaller = GeneratorConfig.cdaJaxbContext.createMarshaller()
		fhirMarshaller.setProperty(Marshaller.JAXB_FORMATTED_OUTPUT, true)
		cdaMarshaller.setProperty(Marshaller.JAXB_FORMATTED_OUTPUT, true)

		private val treatmentBuilder = {
			val (cdaValueBuilder, displayNameProvider) = CdaValueBuilderHelper.get
			new TreatmentBuilder(cdaValueBuilder, displayNameProvider)
		}

		def publish(patient: Patient) {
			publisher.publish(marshalPatient(patient), RabbitMessageQueue.patientRoutingKey)
			for (treatment <- patient.treatments) {
				publisher.publish(marshalTreatment(treatment, patient), RabbitMessageQueue.treatmentRoutingKey)
			}
		}

		private def marshalPatient(patient: Patient): String = {
			val builder = new PatientBuilder
			builder.setMessageInput(patient.toPortavitaPatient)
			builder.build()
			MarshalHelper.marshal(builder.getMessageContent(), fhirMarshaller)
		}

		private def marshalTreatment(treatment: Treatment, subject: Patient): String = {
			val subjectParticipation = subject.toParticipation(treatment.id, treatment.from, treatment.to)
			val performerParticipation = treatment.principalPractitioner.toParticipation(treatment.id, treatment.from, treatment.to)
			val authorParticipation = treatment.principalPractitioner.toParticipation(treatment.id, treatment.from, treatment.to, typeCode = "AUT")
			val portavitaTreatment = treatment.toPortavitaTreatment(subjectParticipation, performerParticipation, authorParticipation)
			treatmentBuilder.setMessageInput(portavitaTreatment)
			treatmentBuilder.build()
			MarshalHelper.marshal(treatmentBuilder.getMessageContent(), cdaMarshaller)
		}
	}
}
