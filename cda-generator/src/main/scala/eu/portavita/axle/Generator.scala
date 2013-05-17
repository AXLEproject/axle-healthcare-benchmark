/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
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
import eu.portavita.axle.model.PatientProfile

/**
 * Application that generates random CDA documents.
 *
 * Using a set of models of health organizations, patients, care provisions,
 * and examinations, the application generates random CDAs and saves them to
 * the specified output directory.
 */
object Generator extends App {

	// Load configuration.
	/** Configuration of the program. */
	val config = ConfigFactory.load()
	/** Directory where the models can be found that . */
	val modelsDirectory = config.getString("modelsDirectory")
	/** Configuration of the program. */
	val outputDirectory = config.getString("outputDirectory")

	// Get local terminology provider.
	private val terminologyDirectory = config.getString("terminologyDirectory")
	/** The terminology cache. */
	val terminology = new LocalTerminologyCache(terminologyDirectory)

	/** Create actor system. */
	implicit val system = ActorSystem("CdaGenerator", config)

	/** The number of CDAs that must be generated. */
	val cdasToGenerate = config.getLong("numberOfCdas")

	// Create examination generator actors for all models in directory.
	private val examinationGenerators = ExaminationGenerator.getGeneratorActors(modelsDirectory, system)
	system.log.info("Created %d examination generators.".format(examinationGenerators.size))

	private val patientProfile = PatientProfile.read(modelsDirectory)
	system.log.info("Loaded patient profile")

	// Create patient generator actor.
	private val patientGenerator = system.actorOf(
		Props(new PatientGenerator(examinationGenerators, patientProfile)),
		name = "patientGenerator")
	system.log.info("Created patient generator.")

	// Create organization generator.
	private val organizationModel = OrganizationModel.read(modelsDirectory)
	system.log.info("Loaded organization mode.")

	private val organizationGenerator = system.actorOf(
		Props(new OrganizationGenerator(organizationModel)),
		name = "organizationGenerator")
	system.log.info("Created organization generator.")

	// Start generating organizations.
	system.log.info("Starting to generate data.")
	for (i <- 1 to config.getInt("nrOfOrganizations")) {
		organizationGenerator ! OrganizationRequest
	}
}
