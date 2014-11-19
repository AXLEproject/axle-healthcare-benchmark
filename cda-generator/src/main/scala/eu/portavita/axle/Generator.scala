/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle

import akka.actor.ActorSystem
import akka.actor.Props
import eu.portavita.axle.generators.BigBang
import eu.portavita.axle.generators.ExaminationGenerator
import eu.portavita.axle.generators.OrganizationGenerator
import eu.portavita.axle.generators.PatientGenerator
import eu.portavita.axle.model.OrganizationModel
import eu.portavita.axle.model.PatientProfile
import eu.portavita.axle.publisher.RabbitMessageQueueActor
import eu.portavita.axle.generators.ConsentGenerator

/**
 * Application that generates random CDA documents.
 *
 * Using a set of models of health organizations, patients, care provisions,
 * and examinations, the application generates random CDAs and saves them to
 * the specified output directory.
 */
object Generator extends App {

	/** Create actor system. */
	implicit val system = ActorSystem("CdaGenerator", GeneratorConfig.config)

	private val publisher = system.actorOf(Props(new RabbitMessageQueueActor), name = "publisher")
	system.log.info("Created Rabbit MQ publisher actor")

	// Create examination generator actors for all models in directory.
	private val examinationGenerators = ExaminationGenerator.getGeneratorActors(GeneratorConfig.modelsDirectory, system)
	system.log.info("Created %d examination generators.".format(examinationGenerators.size))

	private val patientProfile = PatientProfile.read(GeneratorConfig.modelsDirectory)
	system.log.info("Loaded patient profile")
  
  private val consentGenerator = system.actorOf(Props(new ConsentGenerator()), name = "consentGenerator")
  system.log.info("Created consent generator.")

	// Create patient generator actor.
	private val patientGenerator = system.actorOf(
		Props(new PatientGenerator(examinationGenerators, patientProfile)),
		name = "patientGenerator")
	system.log.info("Created patient generator.")

	// Create organization generator.
	private val organizationModel = OrganizationModel.read(GeneratorConfig.modelsDirectory)
	system.log.info("Loaded organization mode.")

	private val organizationGenerator = system.actorOf(
		Props(new OrganizationGenerator(organizationModel)),
		name = "organizationGenerator")
	system.log.info("Created organization generator.")

	private val bigBang = system.actorOf(Props(new BigBang), name = "bigbang")
	system.log.info("Created big bang.")

}
