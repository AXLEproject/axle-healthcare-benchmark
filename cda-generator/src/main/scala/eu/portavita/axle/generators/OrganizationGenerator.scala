/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generators

import scala.util.Random

import akka.actor.Actor
import akka.actor.ActorLogging
import akka.actor.ActorSelection.toScala
import eu.portavita.axle.GeneratorConfig
import eu.portavita.axle.generatable.Organization
import eu.portavita.axle.helper.MarshalHelper
import eu.portavita.axle.model.OrganizationModel
import eu.portavita.axle.publisher.PublishHelper
import eu.portavita.axle.publisher.RabbitMessageQueue
import eu.portavita.databus.messagebuilder.builders.OrganizationBuilder
import eu.portavita.databus.messagebuilder.builders.PractitionerBuilder
import javax.xml.bind.Marshaller

sealed trait OrganizationMessage
case class TopLevelOrganizationRequest extends OrganizationMessage

class OrganizationGenerator(val model: OrganizationModel) extends Actor with ActorLogging {

	lazy private val patientGeneratorActor = context.actorSelection("/user/patientGenerator")

	private val queue = new OrganizationPublisher

	def receive = {
		case TopLevelOrganizationRequest =>
//			System.err.println("TOP LEVEL ORGANIZATION REQUEST")
			generateTopLevelOrganization()

		case x =>
			log.warning("Received message that I cannot handle: " + x.toString)
	}

	private def generateTopLevelOrganization() {
		val organization = generateAndStoreOrganization(None)
		val numberOfSubOrganizations = Random.nextInt(50) + 10
		generateSubOrganizations(organization, numberOfSubOrganizations)
	}

	private def generateSubOrganizations(partOf: Organization, numberOfSubOrganizations: Int) {
		for (i <- 0 to numberOfSubOrganizations) {
			val organization = generateAndStoreOrganization(Some(partOf))
			val numberOfSubSubOrganizations = Random.nextInt(5)
			generateSubSubOrganizations(organization, numberOfSubSubOrganizations)
		}
	}

	private def generateSubSubOrganizations(partOf: Organization, numberOfSubSubOrganizations: Int) {
		for (i <- 0 to numberOfSubSubOrganizations) generateAndStoreOrganization(Some(partOf))
	}

	private def generateAndStoreOrganization(partOf: Option[Organization]): Organization = {
		InPipeline.waitGeneratingOrganizations
//		InPipeline.waitUntilReady
		val organization = Organization.sample(partOf)
		queue.publish(organization)
		generatePatients(organization)
		organization
	}

	private def generatePatients(organization: Organization): Int = {
		val nrOfPatients = model.sampleNrOfPatients
		patientGeneratorActor ! PatientRequest(organization, nrOfPatients)
		val inPipeline = InPipeline.patientRequests.newRequest
		if (inPipeline % 50 == 0) log.info("Requested a new patient, now %d patient requests in pipeline".format(inPipeline))
		nrOfPatients
	}

	class OrganizationPublisher {
		private val publisher = new PublishHelper(context.actorSelection("/user/publisher"))

		private val organizationBuilder = new OrganizationBuilder
		private val practitionerBuilder = new PractitionerBuilder

		private val marshaller = GeneratorConfig.fhirJaxbContext.createMarshaller()
		marshaller.setProperty(Marshaller.JAXB_FORMATTED_OUTPUT, true)

		/**
		 * Publishes the marshalled version of given organization.
		 * @param organization
		 */
		def publish(organization: Organization) {
			organizationBuilder.setMessageInput(organization.toPortavitaOrganization)
			organizationBuilder.build()
			val document = MarshalHelper.marshal(organizationBuilder.getMessageContent(), marshaller)

			publisher.publish(document, RabbitMessageQueue.organizationRoutingKey)
			publishPractitioners(organization)
		}

		private def publishPractitioners(organization: Organization) {
			for (practitioner <- organization.practitioners) {
				practitionerBuilder.setMessageInput(practitioner.toPortavitaEmployee)
				practitionerBuilder.build()
				val document = MarshalHelper.marshal(practitionerBuilder.getMessageContent(), marshaller)
				publisher.publish(document, RabbitMessageQueue.practitionerRoutingKey)
			}
		}
	}
}
