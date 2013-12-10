/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generators

import java.io.File
import java.util.Date

import scala.Array.canBuildFrom
import scala.annotation.tailrec
import scala.util.parsing.json.JSON

import org.hl7.v3.II
import org.hl7.v3.ON
import org.hl7.v3.POCDMT000040AssignedCustodian
import org.hl7.v3.POCDMT000040ClinicalDocument
import org.hl7.v3.POCDMT000040ClinicalDocument
import org.hl7.v3.POCDMT000040Custodian
import org.hl7.v3.POCDMT000040CustodianOrganization

import akka.actor.Actor
import akka.actor.ActorLogging
import akka.actor.ActorRef
import akka.actor.ActorSystem
import akka.actor.Props
import eu.portavita.axle.Generator
import eu.portavita.axle.GeneratorConfig
import eu.portavita.axle.bayesiannetwork.BayesianNetwork
import eu.portavita.axle.bayesiannetwork.DiscreteBayesianNetworkReader
import eu.portavita.axle.bayesiannetwork.NumericBayesianNetworkReader
import eu.portavita.axle.generatable.Examination
import eu.portavita.axle.generatable.Observation
import eu.portavita.axle.generatable.Patient
import eu.portavita.axle.helper.ExaminationDocumentBuilder
import eu.portavita.axle.helper.FilesWriter
import eu.portavita.axle.helper.FilesWriter
import eu.portavita.axle.helper.MarshalHelper
import eu.portavita.axle.helper.RandomHelper
import eu.portavita.axle.json.AsMap
import eu.portavita.axle.json.AsMap
import eu.portavita.axle.messages.ExaminationRequest
import eu.portavita.axle.messages.ExaminationRequest
import eu.portavita.terminology.CodeSystem
import eu.portavita.terminology.CodeSystem
import eu.portavita.terminology.HierarchyNode

/**
 * Generates random examinations and saves the CDA to disk.
 *
 * Actor that upon receiving examination requests generates a new random
 * examination, builds a CDA, and saves the CDA to disk.
 *
 * @param code
 */
class ExaminationGenerator(
	val code: String,
	val discreteBayesianNetwork: Option[BayesianNetwork] = None,
	val numericBayesianNetwork: Option[BayesianNetwork] = None,
	val missingValuesBayesianNetwork: Option[BayesianNetwork] = None
) extends Actor with ActorLogging {

	// Code system of the examination's code
	val codeSystem = CodeSystem.guess(code)

	val provider = new ExaminationDataProvider
	val builder = new eu.portavita.builder.ExaminationDocumentBuilder(GeneratorConfig.terminology, provider)

	private val marshaller = Generator.cdaJaxbContext.createMarshaller()

	private val writer = new FilesWriter()

	/**
	 * The hierarchy of this examination as stored by Portavita.
	 */
	private lazy val hierarchy: HierarchyNode = GeneratorConfig.terminology.getHierarchy(codeSystem, code)

	/**
	 * Receives and processes a message from another actor.
	 */
	def receive = {
		case request @ ExaminationRequest(_,_) =>
			val examination = sampleNonEmptyExamination(request)
			val document = buildDocument(examination)
			writer.write(MarshalHelper.marshal(document, marshaller))

		case x =>
			log.warning("Received message that I cannot handle: " + x.toString)
	}

	lazy val custodian = {
		val custodian = new POCDMT000040Custodian()
		val assignedCustodian = new POCDMT000040AssignedCustodian()
		val custodianOrganization = new POCDMT000040CustodianOrganization()
		val name = new ON()
		name.getContent().add("AXLE CDA Generator")
		custodianOrganization.setName(name)
		val id = new II()
		id.setExtension("0")
		id.setRoot("2.16.840.1.113883.2.4.3.31.3.2")
		custodianOrganization.getId().add(id)
		assignedCustodian.setRepresentedCustodianOrganization(custodianOrganization)
		custodian.setAssignedCustodian(assignedCustodian)
		custodian
	}

	@tailrec
	final def sampleNonEmptyExamination(request: ExaminationRequest): Examination = {
		val exam = sample(request)
		if (exam.hasValues) exam
		else sampleNonEmptyExamination(request)
	}

	/**
	 * Returns a new random examination.
	 * @return
	 */
	private def sample(request: ExaminationRequest): Examination = {

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

		val practitioner = RandomHelper.randomElement(request.patient.organization.practitioners)
		new Examination(request.patient, code, request.date, discreteObservations ++ filteredNumericObservations, practitioner)
	}

	private def buildDocument(examination: Examination): POCDMT000040ClinicalDocument = {
		val hl7Examination = examination.buildHierarchy(hierarchy)
		val id = provider.add(examination, hl7Examination)
		builder.create(id)
	}
}

object ExaminationGenerator {
	/**
	 * Returns a map of examination codes onto references to actors that generate examinations of that type.
	 * Namely, for each model in the given directory, an examination generator actor
	 * is created and returned.
	 *
	 * @param modelsDirectory
	 * @param system
	 * @return
	 */
	def getGeneratorActors(modelsDirectory: String, system: ActorSystem): Map[String, ActorRef] = {
		val actorRefs =
			for (
				(examinationCode, file) <- getModelFiles(modelsDirectory);
				content = scala.io.Source.fromFile(file).mkString.replaceAll("\"NaN\"", "0");
				generator <- fromJson(system, examinationCode, content);
				if generator.isDefined
			) yield {
				(examinationCode, generator.get)
			}

		actorRefs.toMap
	}

	/**
	 * Returns a set of tuples with the examination act code and the json file.
	 *
	 * @param directory
	 * @return
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


	/**
	 * Returns actor references within the given actor system from the given json string
	 * for the examination with the given code.
	 *
	 * @param system
	 * @param examinationCode
	 * @return
	 */
	def fromJson(system: ActorSystem, examinationCode: String, jsonString: String): List[Option[ActorRef]] = {

		val parsedJson = JSON.parseFull(jsonString)
		if (parsedJson.isEmpty) throw new IllegalArgumentException("Unable to parse JSON for examination " + examinationCode)

		for (Some(AsMap(main)) <- List(parsedJson)) yield {

			// Try to read the network for the discrete observations
			val discreteNetwork =
				try {
					val AsMap(discrete) = main.get("discrete").get
					Some(DiscreteBayesianNetworkReader.read(examinationCode, discrete))
				} catch {
					case _: Throwable => None
				}

			val numericJson = main.get("numeric")

			// Try to read the network for the numeric observations
			val numericNetwork =
				try {
					val AsMap(numeric) = numericJson.get
					val AsMap(network) = numeric.get("network").get
					Some(NumericBayesianNetworkReader.read(examinationCode, network))
				} catch {
					case _: Throwable => None
				}

			// Try to read the network for the missing value patterns in the numeric network
			val missingValuesNetwork =
				try {
					val AsMap(numeric) = numericJson.get
					val AsMap(missingValues) = numeric.get("missingValues").get
					Some(DiscreteBayesianNetworkReader.read(examinationCode, missingValues))
				} catch {
					case _: Throwable => None
				}

			// Create generator actor if there is either a discrete nor numeric network defined
			if (discreteNetwork.isDefined || (numericNetwork.isDefined && missingValuesNetwork.isDefined)) {
				// Create examination generator actor based on the model
				Some(system.actorOf(
					Props(
						new ExaminationGenerator(
							examinationCode,
							discreteBayesianNetwork = discreteNetwork,
							numericBayesianNetwork = numericNetwork,
							missingValuesBayesianNetwork = missingValuesNetwork))
						.withDispatcher("my-dispatcher"),
					name = examinationCode)
				)
			} else {
				None
			}
		}
	}
}

