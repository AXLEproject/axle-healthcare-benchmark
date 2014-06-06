/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generators

import java.util.Calendar
import java.util.Date
import scala.util.Random
import akka.actor.Actor
import akka.actor.ActorLogging
import akka.actor.ActorSelection.toScala
import eu.portavita.axle.GeneratorConfig
import eu.portavita.axle.generatable.Address
import eu.portavita.axle.generatable.Organization
import eu.portavita.axle.helper.MarshalHelper
import eu.portavita.axle.model.OrganizationModel
import eu.portavita.axle.publisher.PublishHelper
import eu.portavita.axle.publisher.RabbitMessageQueue
import eu.portavita.databus.messagebuilder.builders.OrganizationBuilder
import eu.portavita.databus.messagebuilder.builders.PractitionerBuilder
import javax.xml.bind.Marshaller
import java.util.GregorianCalendar
import eu.portavita.databus.messagebuilder.cda.factory.ClinicalDocumentMessageContentFactory
import eu.portavita.databus.messagebuilder.cda.factory.CustodianOrganizationFactory
import eu.portavita.databus.messagebuilder.cda.factory.IdentifierFactory

sealed trait OrganizationMessage
case class TopLevelOrganizationRequest extends OrganizationMessage

class OrganizationGenerator(val model: OrganizationModel) extends Actor with ActorLogging {

	private var nrOfGeneratedCaregroups = 0
	private var nrOfGeneratedOrganizations= 0

	lazy private val patientGeneratorActor = context.actorSelection("/user/patientGenerator")

	private val queue = new OrganizationPublisher

	override def preStart() {
		super.preStart()
		val custodianOrganization = createCustodianOrganization
		setCustodianOrganization(custodianOrganization)
	}

	def receive = {
		case TopLevelOrganizationRequest =>
			if (GeneratorConfig.mayGenerateNewCaregroup(nrOfGeneratedCaregroups)) {
				generateTopLevelOrganization()
				nrOfGeneratedCaregroups += 1
			} else {
				log.info("Not generating new caregroup because %d caregroups were created and %d is the max".format(nrOfGeneratedCaregroups, GeneratorConfig.maxNrOfCaregroups))
			}

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
		val organization = Organization.sample(model, partOf)
		if (GeneratorConfig.mayGenerateNewOrganization(nrOfGeneratedOrganizations)) {
			InPipeline.waitGeneratingOrganizations
			queue.publish(organization)
			generatePatients(organization)
			nrOfGeneratedOrganizations += 1
		} else {
			log.info("Not generating new organization because %d organizations were created and %d is the max".format(nrOfGeneratedOrganizations, GeneratorConfig.maxNrOfOrganizations))
		}
		organization
	}

	private def generatePatients(organization: Organization) {
		patientGeneratorActor ! PatientRequest(organization)
		val inPipeline = InPipeline.patientRequests.newRequest
		if (inPipeline % 500 == 0) log.info("Requested a new patient, now %d patient requests in pipeline".format(inPipeline))
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

	private def setCustodianOrganization(custodianOrganization: Organization) {
		val id = IdentifierFactory.entityId(custodianOrganization.id)
		val representedCustodian = CustodianOrganizationFactory.create(id, custodianOrganization.name)
		ClinicalDocumentMessageContentFactory.PORTAVITA_CUSTODIAN.getAssignedCustodian().setRepresentedCustodianOrganization(representedCustodian)
		queue.publish(custodianOrganization)
	}

	private def createCustodianOrganization: Organization = {
		val id = 0
		val agb = Random.nextInt(99999999)
		val startDate = new GregorianCalendar(2002, 1, 2).getTime()
		val address = new Address("WP", "Amsterdam", "1018MR", "The Netherlands", startDate, null, "Oostenburgervoorstraat 100", "")
		new Organization(id, "%08d".format(agb), "ORG", "Portavita B.V.", startDate, address, None, Nil, 0)
	}
}
