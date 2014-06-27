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
import eu.portavita.axle.generatable.Practitioner

sealed trait OrganizationMessage
case class TopLevelOrganizationRequest() extends OrganizationMessage

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
		val careGroup = storeOrganization(Organization.sampleCareGroup)
		val numberOfSubOrganizations = Random.nextInt(50) + 10
		generateSubOrganizations(careGroup, numberOfSubOrganizations)
	}

	private def generateSubOrganizations(partOf: Organization, numberOfSubOrganizations: Int) {
		for (i <- 0 to numberOfSubOrganizations) {
			if (GeneratorConfig.mayGenerateNewOrganization(nrOfGeneratedOrganizations)) {
				val organization = storeOrganization(Organization.sample(model, partOf))
				nrOfGeneratedOrganizations += 1
				val numberOfSubSubOrganizations = Random.nextInt(5)
				generateSubSubOrganizations(organization, numberOfSubSubOrganizations)
			}
		}
	}

	private def generateSubSubOrganizations(partOf: Organization, numberOfSubSubOrganizations: Int) {
		for (i <- 0 to numberOfSubSubOrganizations) {
			if (GeneratorConfig.mayGenerateNewOrganization(nrOfGeneratedOrganizations)) {
				val organization = storeOrganization(Organization.sample(model, partOf))
				nrOfGeneratedOrganizations += 1
			}
		}
	}

	private def storeOrganization(organization: Organization): Organization = {
		InPipeline.waitGeneratingOrganizations
		queue.publish(organization)
		generatePatients(organization)
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
			organizationBuilder.setMessageInput(organization.toOrganizationDTO)
			organizationBuilder.build()
			val document = MarshalHelper.marshal(organizationBuilder.getMessageContent(), marshaller)

			publisher.publish(document, RabbitMessageQueue.organizationRoutingKey)
			publishPractitioners(organization)
		}

		private def publishPractitioners(organization: Organization) {
			publishPractitioners(organization.careGroupEmployees)
			publishPractitioners(organization.researchers)
			publishPractitioners(organization.practitioners)
		}

		private def publishPractitioners(practitioners: List[Practitioner]) {
			for (practitioner <- practitioners) {
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
		new Organization(id, "%08d".format(agb), "ORG", "Portavita B.V.", startDate, address, None, Nil, Nil, Nil, 0)
	}
}
