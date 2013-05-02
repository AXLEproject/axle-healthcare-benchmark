package eu.portavita.axle

import com.typesafe.config.ConfigFactory

import akka.actor.ActorSystem
import akka.actor.Props
import akka.actor.actorRef2Scala
import eu.portavita.axle.generators.ExaminationGenerator
import eu.portavita.axle.generators.OrganizationGenerator
import eu.portavita.axle.generators.PatientGenerator
import eu.portavita.axle.messages.OrganizationRequest
import eu.portavita.axle.model.OrganizationModel
import eu.portavita.terminology.LocalTerminologyCache

/**
 * Application that generates CDA documents.
 */
object Generator extends App {

	// Load configuration.
	val config = ConfigFactory.load()
	val modelsDirectory = config.getString("modelsDirectory")
	val outputDirectory = config.getString("outputDirectory")

	// Get local terminology provider.
	val terminologyDirectory = config.getString("terminologyDirectory")
	val terminology = new LocalTerminologyCache(terminologyDirectory)

	// Create actor system.
	implicit val system = ActorSystem("CdaGenerator", config)

	// Create examination generator actors for all models in directory.
	val examinationGenerators = ExaminationGenerator.getGeneratorActors(modelsDirectory, system)
	system.log.info("Created %d examination generators.".format(examinationGenerators.size))

	// Create patient generator actor.
	val patientGenerator = system.actorOf(
		Props(new PatientGenerator(examinationGenerators)),
		name = "patientGenerator")
	system.log.info("Created patient generator.")

	// Create organization generator.
	val organizationModel = OrganizationModel.read(modelsDirectory)
	system.log.info("Loaded organization mode.")

	val organizationGenerator = system.actorOf(
		Props(new OrganizationGenerator(organizationModel)),
		name = "organizationGenerator")
	system.log.info("Created organization generator.")

	// Start generating organizations.
	system.log.info("Starting to generate data.")
	for (i <- 1 to config.getInt("nrOfOrganizations")) {
		organizationGenerator ! OrganizationRequest
	}
}
