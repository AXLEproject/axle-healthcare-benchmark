/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generators

import java.io.File
import java.util.Date
import scala.Array.canBuildFrom
import scala.annotation.tailrec
import scala.util.parsing.json.JSON
import akka.actor.Actor
import akka.actor.ActorLogging
import akka.actor.ActorRef
import akka.actor.ActorSelection.toScala
import akka.actor.ActorSystem
import akka.actor.Props
import eu.portavita.axle.GeneratorConfig
import eu.portavita.axle.bayesiannetwork.BayesianNetwork
import eu.portavita.axle.bayesiannetwork.DiscreteBayesianNetworkReader
import eu.portavita.axle.bayesiannetwork.NumericBayesianNetworkReader
import eu.portavita.axle.generatable.Examination
import eu.portavita.axle.generatable.Observation
import eu.portavita.axle.generatable.Patient
import eu.portavita.axle.helper.CdaValueBuilderHelper
import eu.portavita.axle.helper.MarshalHelper
import eu.portavita.axle.helper.RandomHelper
import eu.portavita.axle.json.AsMap
import eu.portavita.axle.publisher.PublishHelper
import eu.portavita.axle.publisher.RabbitMessageQueue
import eu.portavita.databus.messagebuilder.builders.ExaminationBuilder
import eu.portavita.terminology.CodeSystem
import eu.portavita.terminology.HierarchyNode
import javax.xml.bind.Marshaller
import eu.portavita.databus.message.contents.ExaminationMessageContent
import eu.portavita.axle.helper.CodeSystemProvider
import org.hl7.v3.StrucDocText
import org.apache.commons.io.input.TeeInputStream

sealed trait ExaminationMessage
case class ExaminationGenerationRequest(val patient: Patient, val performanceDates: IndexedSeq[Date]) extends ExaminationMessage

/**
 * Generates random examinations, serializes them to CDA, and sends the CDAs to the publisher actor.
 */
class ExaminationGenerator(
	val code: String,
	val codeSystem: CodeSystem,
	val hierarchy: HierarchyNode,
	val discreteBayesianNetwork: Option[BayesianNetwork] = None,
	val numericBayesianNetwork: Option[BayesianNetwork] = None,
	val missingValuesBayesianNetwork: Option[BayesianNetwork] = None) extends Actor with ActorLogging {

	private val queue = new ExaminationPublisher

	/**
	 * Receives and processes a message from another actor.
	 */
	def receive = {
		case request @ ExaminationGenerationRequest(patient, performanceDates) =>
			InPipeline.waitGeneratingExaminations
			for (performanceDate <- performanceDates) generate(patient, performanceDate)
			val inPipeline = InPipeline.examinationRequests.finishRequest
			if (inPipeline % 2500 == 0) log.info("%d examination requests in pipeline".format(inPipeline))

		case x =>
			log.warning("Received message that I cannot handle: " + x.toString)
	}

	private def generate(patient: Patient, performanceDate: Date) {
		val examination = sampleNonEmptyExamination(patient, performanceDate)
		queue.publish(examination)
	}

	@tailrec
	final def sampleNonEmptyExamination(patient: Patient, performanceDate: Date): Examination = {
		val exam = sample(patient, performanceDate)
		if (exam.hasValues) exam
		else sampleNonEmptyExamination(patient, performanceDate)
	}

	/**
	 * Returns a new random examination.
	 * @return
	 */
	private def sample(patient: Patient, performanceDate: Date): Examination = {

		def sampleNetwork(net: Option[BayesianNetwork]): Map[String, Observation] = net match {
			case Some(network) => network.sample
			case None => Map.empty[String, Observation]
		}

		val discreteObservations = sampleNetwork(discreteBayesianNetwork)
		val allNumericObservations = sampleNetwork(numericBayesianNetwork)
		val filteredNumericObservations = missingValuesBayesianNetwork match {
			case Some(net) =>
				val mv = net.sample
				for ((code, missing) <- mv if missing.hasValue)
					yield code -> allNumericObservations.get(code).get
			case None => Map()
		}

		val practitioner = RandomHelper.randomElement(patient.organization.practitioners)
		new Examination(patient, code, performanceDate, discreteObservations ++ filteredNumericObservations, practitioner)
	}

	class ExaminationPublisher {
		private val publisher = new PublishHelper(context.actorSelection("/user/publisher"))

		private val examinationBuilder: ExaminationBuilder = {
			val (cdaValueBuilder, displayNameProvider) = CdaValueBuilderHelper.get
			new ExaminationBuilder(cdaValueBuilder, displayNameProvider)
		}

		private val marshaller: Marshaller = {
			val m = GeneratorConfig.cdaJaxbContext.createMarshaller()
			m.setProperty(Marshaller.JAXB_FORMATTED_OUTPUT, true)
			m
		}

		def publish(examination: Examination) {
			val message = buildExaminationMessage(examination)
			addText(examination.generateText(), message)
			val marshalledMessage = MarshalHelper.marshal(message, marshaller)
			publisher.publish(marshalledMessage, RabbitMessageQueue.examinationRoutingKey)
		}

		def addText(text: String, message: ExaminationMessageContent) {
			val textElement = new StrucDocText
			textElement.getContent().add(text)
			message.getExaminationSections().get(0).setText(textElement)
		}

		private def buildExaminationMessage(examination: Examination): ExaminationMessageContent = {
			val hl7Examination = examination.build(hierarchy)
			examinationBuilder.setMessageInput(hl7Examination)
			examinationBuilder.build()
			examinationBuilder.getMessageContent()
		}
	}
}

object ExaminationGenerator {
	val jsonFileNameRegex = "^([^\\.]+)\\.json$".r

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

		for (
			file <- jsonFiles;
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
				val codeSystem = CodeSystemProvider.get(examinationCode)
				// Create examination generator actor based on the model
				Some(system.actorOf(
					Props(
						new ExaminationGenerator(
							examinationCode,
							codeSystem,
							GeneratorConfig.terminology.getHierarchy(codeSystem, examinationCode),
							discreteBayesianNetwork = discreteNetwork,
							numericBayesianNetwork = numericNetwork,
							missingValuesBayesianNetwork = missingValuesNetwork))
						.withDispatcher("my-dispatcher"),
					name = examinationCode))
			} else {
				None
			}
		}
	}
}

