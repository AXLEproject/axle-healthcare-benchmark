/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generators

import akka.actor.Actor
import akka.actor.ActorLogging
import eu.portavita.axle.generatable.Organization
import eu.portavita.axle.messages.OrganizationRequest
import eu.portavita.axle.messages.PatientRequest
import eu.portavita.axle.model.OrganizationModel

class OrganizationGenerator(
	val model: OrganizationModel) extends Actor with ActorLogging {

	lazy private val patientGeneratorActor =
		context.actorFor("/user/patientGenerator")

	def receive = {
		case OrganizationRequest =>
			val organization = Organization.sample

			// Generate patients
			val nrOfPatients = model.sampleNrOfPatients
			for (i <- 1 to nrOfPatients) {
				patientGeneratorActor ! PatientRequest(organization)
			}

		case x =>
			log.warning("Received message that I cannot handle: " + x.toString)
	}
}
