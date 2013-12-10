/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generators

import scala.util.Random

import akka.actor.Actor
import akka.actor.ActorLogging
import akka.actor.actorRef2Scala
import eu.portavita.axle.Generator
import eu.portavita.axle.generatable.Organization
import eu.portavita.axle.helper.MarshalHelper
import eu.portavita.axle.messages.PatientRequest
import eu.portavita.axle.messages.PatientRequest
import eu.portavita.axle.messages.TopLevelOrganizationRequest
import eu.portavita.axle.messages.TopLevelOrganizationRequest
import eu.portavita.axle.model.OrganizationModel
import eu.portavita.axle.model.OrganizationModel
import eu.portavita.axle.publisher.RabbitMessageQueue
import eu.portavita.databus.messagebuilder.builders.OrganizationBuilder
import eu.portavita.databus.messagebuilder.builders.PractitionerBuilder


class OrganizationGenerator(
	val model: OrganizationModel,
	val outputDirectory: String) extends Actor with ActorLogging {

	private val marshaller = Generator.fhirJaxbContext.createMarshaller()

	lazy private val patientGeneratorActor = context.actorFor("/user/patientGenerator")
	private val publisher = new RabbitMessageQueue

	def receive = {
		case TopLevelOrganizationRequest =>
			val careGroupOrganizations = generateTopLevelOrganization()

		case x =>
			log.warning("Received message that I cannot handle: " + x.toString)
	}

	private def generateTopLevelOrganization() {
		val organization = Organization.sample(None)
		store(organization)
		generatePatients(organization)
		for (i <- 0 to Random.nextInt(100) + 25) generateSubOrganization(organization)
	}

	private def generateSubOrganization(partOf: Organization) {
		val organization = Organization.sample(Some(partOf))
		store(organization)
		generatePatients(organization)
		generateSubSubOrganizations(organization)
	}

	private def generateSubSubOrganizations(partOf: Organization) {
		for (i <- 0 to Random.nextInt(10)) store(Organization.sample(Some(partOf)))
	}

	private def generatePatients(organization: Organization) {
		val nrOfPatients = model.sampleNrOfPatients
		for (i <- 1 to nrOfPatients) patientGeneratorActor ! PatientRequest(organization)
	}

	/**
	 * Saves the marshalled version of given organization to disk.
	 * @param organization
	 */
	private def store(organization: Organization) {
		val builder = new OrganizationBuilder
		builder.setMessageInput(organization.toPortavitaOrganization)
		builder.build()
		val document = MarshalHelper.marshal(builder.getMessageContent(), marshaller)

		publisher.publish(document, "source.generator.type.fhir.organization.insert")
		storePractitioners(organization)
	}

	private def storePractitioners(organization: Organization) {
		val builder = new PractitionerBuilder

		for (practitioner <- organization.practitioners) {
			builder.setMessageInput(practitioner.toPortavitaEmployee)
			builder.build()
			val document = MarshalHelper.marshal(builder.getMessageContent(), marshaller)
			publisher.publish(document, "source.generator.type.fhir.practitioner.insert")
		}
	}
}

