/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generators

import java.io.File

import scala.Array.canBuildFrom
import scala.annotation.tailrec
import scala.util.parsing.json.JSON

import akka.actor.Actor
import akka.actor.ActorLogging
import akka.actor.ActorRef
import akka.actor.ActorSystem
import akka.actor.Props
import eu.portavita.axle.Generator
import eu.portavita.axle.actors.ExaminationDocumentBuilder
import eu.portavita.axle.actors.FilesWriter
import eu.portavita.axle.actors.Marshal
import eu.portavita.axle.bayesiannetwork.BayesianNetwork
import eu.portavita.axle.bayesiannetwork.DiscreteBayesianNetworkReader
import eu.portavita.axle.bayesiannetwork.NumericBayesianNetworkReader
import eu.portavita.axle.generatable.Examination
import eu.portavita.axle.generatable.Observation
import eu.portavita.axle.json.AsMap
import eu.portavita.axle.messages.ExaminationRequest
import eu.portavita.terminology.CodeSystem

class ExaminationGenerator(
	val code: String,
	val discreteBayesianNetwork: Option[BayesianNetwork] = None,
	val numericBayesianNetwork: Option[BayesianNetwork] = None,
	val missingValuesBayesianNetwork: Option[BayesianNetwork] = None
) extends Actor with ActorLogging {

	// Code system of the examination's code
	val codeSystem = CodeSystem.guess(code)

	private val documentBuilder = new ExaminationDocumentBuilder()
	private val marshaller = new Marshal()
	private val writer = new FilesWriter()

	/**
	 * The hierarchy of this examination as stored by Portavita.
	 */
	private lazy val hierarchy = Generator.terminology.getHierarchy(codeSystem, code)

	/**
	 * Receives and processes a message from another actor.
	 */
	def receive = {
		case ExaminationRequest(patient, performedOn) =>
			val examination = sampleNonEmptyExamination
			examination.date = Some(performedOn)

			// Examination must have values
			assert(examination.hasValues)

			val hl7Examination = examination.buildHierarchy(hierarchy)
			val document = documentBuilder.create(patient, hl7Examination)

			writer.write(marshaller.create(document))


		case x =>
			log.warning("Received message that I cannot handle: " + x.toString)
	}

	@tailrec
	final def sampleNonEmptyExamination: Examination = {
		val exam = sample
		if (exam.hasValues) exam
		else sampleNonEmptyExamination
	}

	/**
	 * Returns a new random examination.
	 */
	private def sample: Examination = {

		val discreteObservations =
			if (discreteBayesianNetwork.isDefined) discreteBayesianNetwork.get.sample
			else Map[String, Observation]()

		val allNumericObservations =
			if (numericBayesianNetwork.isDefined) numericBayesianNetwork.get.sample
			else Map[String, Observation]()

		val filteredNumericObservations =
			if (missingValuesBayesianNetwork.isDefined) {
				val mv = missingValuesBayesianNetwork.get.sample

				for ((code, missing) <- mv if missing.hasValue)
					yield code -> allNumericObservations.get(code).get

			} else Map()

		new Examination(code, discreteObservations ++ filteredNumericObservations)
	}
}

object ExaminationGenerator {
	/**
	 * Returns a list of actor refs that refer to actors that generate examinations.
	 * Namely, for each model in the given directory, an examination generator actor
	 * is created and returned.
	 */
	def getGeneratorActors(modelsDirectory: String, system: ActorSystem): Map[String, ActorRef] = {
		val actorRefs =
			for (
				(examinationName, file) <- getModelFiles(modelsDirectory);
				content = scala.io.Source.fromFile(file).mkString.replaceAll("\"NaN\"", "0");
				generator <- fromJson(system, examinationName, content);
				if generator.isDefined
			) yield {
				(examinationName, generator.get)
			}

		actorRefs.toMap
	}

	/**
	 * Returns a set of tuples with the examination act code and the json file.
	 */
	def getModelFiles(directory: String) = {
		val examinationDirectory = new java.io.File(directory + File.separator + "examinations")
		val jsonFiles = examinationDirectory.listFiles.filter(_.getName.endsWith(".json"))

		val jsonFileNameRegex = "^([^\\.]+)\\.json$".r
		for (file <- jsonFiles;
			jsonFileNameRegex(examinationName) = file.getName()
		) yield {
			(examinationName, file)
		}
	}


	def fromJson(system: ActorSystem, examinationName: String, jsonString: String): List[Option[ActorRef]] = {

		val parsedJson = JSON.parseFull(jsonString)
		if (parsedJson.isEmpty) throw new IllegalArgumentException("Unable to parse JSON for examination " + examinationName)

		for (Some(AsMap(main)) <- List(parsedJson)) yield {

			// Try to read the network for the discrete observations
			val discreteNetwork =
				try {
					val AsMap(discrete) = main.get("discrete").get
					Some(DiscreteBayesianNetworkReader.read(examinationName, discrete))
				} catch {
					case _: Throwable => None
				}

			val numericJson = main.get("numeric")

			// Try to read the network for the numeric observations
			val numericNetwork =
				try {
					val AsMap(numeric) = numericJson.get
					val AsMap(network) = numeric.get("network").get
					Some(NumericBayesianNetworkReader.read(examinationName, network))
				} catch {
					case _: Throwable => None
				}

			// Try to read the network for the missing value patterns in the numeric network
			val missingValuesNetwork =
				try {
					val AsMap(numeric) = numericJson.get
					val AsMap(missingValues) = numeric.get("missingValues").get
					Some(DiscreteBayesianNetworkReader.read(examinationName, missingValues))
				} catch {
					case _: Throwable => None
				}

			// Create generator actor if there is either a discrete nor numeric network defined
			if (discreteNetwork.isDefined || (numericNetwork.isDefined && missingValuesNetwork.isDefined)) {
				// Create examination generator actor based on the model
				Some(system.actorOf(
					Props(
						new ExaminationGenerator(
							examinationName,
							discreteBayesianNetwork = discreteNetwork,
							numericBayesianNetwork = numericNetwork,
							missingValuesBayesianNetwork = missingValuesNetwork))
						.withDispatcher("my-dispatcher"),
					name = examinationName)
				)
			} else {
				None
			}
		}
	}

}

