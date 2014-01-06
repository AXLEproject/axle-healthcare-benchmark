/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generators

import java.io.File

import scala.util.Random

import akka.actor.Actor
import akka.actor.ActorLogging
import akka.actor.actorRef2Scala
import eu.portavita.axle.generatable.Organization
import eu.portavita.axle.helper.FilesWriter
import eu.portavita.axle.messages.PatientRequest
import eu.portavita.axle.messages.TopLevelOrganizationRequest
import eu.portavita.axle.model.OrganizationModel
import eu.portavita.databus.messagebuilder.JaxbHelper
import eu.portavita.databus.messagebuilder.builders.OrganizationBuilder
import eu.portavita.databus.messagebuilder.builders.PractitionerBuilder

class OrganizationGenerator(
	val model: OrganizationModel,
	val outputDirectory: String) extends Actor with ActorLogging {

	lazy private val patientGeneratorActor = context.actorFor("/user/patientGenerator")

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
		val directoryPath = outputDirectory + organization.directoryName

		val builder = new OrganizationBuilder
		builder.setMessageInput(organization.toPortavitaOrganization)
		builder.build()
		val document = JaxbHelper.marshal(builder.getMessageContent())

		val fileName = organization.name + ".xml"
		FilesWriter.write(directoryPath, fileName, document)

		storePractitioners(organization)
	}

	private def storePractitioners(organization: Organization) {
		val builder = new PractitionerBuilder
		val directoryPath = outputDirectory + organization.directoryName + File.separator + "practitioners"

		for (practitioner <- organization.practitioners) {
			builder.setMessageInput(practitioner.toPortavitaEmployee)
			builder.build()
			val document = JaxbHelper.marshal(builder.getMessageContent())
			val fileName = "practitioner-" + practitioner.roleId + ".xml"
			FilesWriter.write(directoryPath, fileName, document)
		}
	}
}

