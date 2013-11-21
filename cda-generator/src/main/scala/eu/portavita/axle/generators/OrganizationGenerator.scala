/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generators

import java.io.File
import java.io.FileWriter
import scala.annotation.tailrec
import scala.util.Random
import akka.actor.Actor
import akka.actor.ActorLogging
import akka.actor.actorRef2Scala
import eu.portavita.axle.generatable.Organization
import eu.portavita.axle.messages.CareGroupRequest
import eu.portavita.axle.messages.PatientRequest
import eu.portavita.axle.model.OrganizationModel
import eu.portavita.databus.messagebuilder.builders.OrganizationBuilder
import eu.portavita.databus.messagebuilder.fhir.FhirResourceMarshaller
import eu.portavita.axle.messages.CareGroupRequest
import eu.portavita.axle.messages.PatientRequest

class OrganizationGenerator(
	val model: OrganizationModel,
	val outputDirectory: String) extends Actor with ActorLogging {

	lazy private val patientGeneratorActor = context.actorFor("/user/patientGenerator")
	lazy private val fhirMarshaller = new FhirResourceMarshaller()

	def receive = {
		case CareGroupRequest =>
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

		// Generate sub sub organizations
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
		val directoryPath = outputDirectory + getDirectoryFor(organization = organization)
		val directoryFile = new File(directoryPath)
		if (!directoryFile.exists()) directoryFile.mkdirs()

		val builder = new OrganizationBuilder
		builder.setMessageInput(organization.toPortavitaOrganization)
		val organizationMessage = builder.build()
		val document = fhirMarshaller.marshal(organizationMessage)

		val fileName = directoryPath + File.separator + nameFor(organization) + ".xml"
		val outputFile = new FileWriter(fileName)
		outputFile.write(document)
		outputFile.close()
	}

	/**
	 * Returns the directory name for the given organization.
	 * @return relative directory path
	 */
	@tailrec
	final def getDirectoryFor(postfix: String = "", organization: Organization): String = {
		def addTo(organization: Organization, postfix: String): String = {
			if (postfix.isEmpty()) nameFor(organization)
			else nameFor(organization) + File.separator + postfix
		}
		organization.partOf match {
			case None => nameFor(organization) + File.separator + postfix
			case partOf: Option[Organization] => getDirectoryFor(addTo(organization, postfix), partOf.get)
		}
	}

	private def nameFor(organization: Organization): String = "organization-" + organization.id
}

