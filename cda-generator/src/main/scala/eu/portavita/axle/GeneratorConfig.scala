package eu.portavita.axle

import com.typesafe.config.ConfigFactory

import eu.portavita.axle.generators.PipelineConfig
import eu.portavita.axle.helper.CdaValueBuilderHelper
import eu.portavita.axle.publisher.RabbitMessageQueueConfig
import eu.portavita.databus.message.contents.CdaJaxbContext
import eu.portavita.databus.message.contents.FhirJaxbContext
import eu.portavita.terminology.LocalTerminologyCache

object GeneratorConfig {
	val config = ConfigFactory.load()

	val modelsDirectory = config.getString("modelsDirectory")
	val terminologyDirectory = config.getString("terminologyDirectory")

	/** The terminology cache. */
	val terminology = new LocalTerminologyCache(terminologyDirectory)
	val unitMap = readUnitMap(terminologyDirectory + "/units.csv")
	val valueTypeProvider = CdaValueBuilderHelper.getValueTypeProvider

	val cdaJaxbContext = new CdaJaxbContext
	val fhirJaxbContext = new FhirJaxbContext

	val rabbitConfig = new RabbitMessageQueueConfig(
		username = config.getString("rabbit.username"),
		password = config.getString("rabbit.password"),
		host = config.getString("rabbit.host"),
		virtualHost = config.getString("rabbit.virtualhost"),
		exchangeName = config.getString("rabbit.exchangeName"),
		exchangeType = config.getString("rabbit.exchangeType"),
		durable = config.getBoolean("rabbit.durable"),
		autoDelete = config.getBoolean("rabbit.autoDelete"))

	val pipelineConfig = new PipelineConfig(
		maxPublishRequests = config.getInt("maxInPipeline.publishRequests"),
		maxOrganizations = config.getInt("maxInPipeline.organizations"),
		maxPatients = config.getInt("maxInPipeline.patients"),
		maxExaminations = config.getInt("maxInPipeline.examinations"))

	val maxNrOfCaregroups = config.getInt("generate.max.caregroups")
	val maxNrOfOrganizations = config.getInt("generate.max.organizations")

	/**
	 * Reads a map from act code onto used unit from the given file.
	 *
	 * @param fileName Name of file that contains the unit information.
	 *
	 * @return map from act code onto used unit
	 */
	def readUnitMap(filename: String): Map[String, String] = {
		val entries = scala.io.Source.fromFile(filename)

		(for (entry <- entries.getLines) yield {
			val parts = entry.split(",")
			val code = parts(0)
			val unit = parts(1)
			(code, unit)
		}) toMap
	}

	def mayGenerateNewCaregroup(nrOfCaregroups: Int) = maxNrOfCaregroups == 0 || nrOfCaregroups < maxNrOfCaregroups
	def mayGenerateNewOrganization(nrOfOrganizations: Int) = maxNrOfOrganizations == 0 || nrOfOrganizations < maxNrOfOrganizations
}
