package eu.portavita.axle

import com.typesafe.config.ConfigFactory
import eu.portavita.terminology.LocalTerminologyCache
import eu.portavita.axle.publisher.RabbitMessageQueueConfig

object GeneratorConfig {
	val config = ConfigFactory.load()

	val modelsDirectory = config.getString("modelsDirectory")
	val outputDirectory = config.getString("outputDirectory")
	val terminologyDirectory = config.getString("terminologyDirectory")

	/** The terminology cache. */
	val terminology = new LocalTerminologyCache(terminologyDirectory)
	val unitMap = readUnitMap(terminologyDirectory + "/units.csv")

	val nrOfOrganizations = config.getInt("nrOfOrganizations")
	val cdasToGenerate = config.getLong("numberOfCdas")

	val rabbitConfig = new RabbitMessageQueueConfig(
		host         = config.getString("rabbit.host"),
		exchangeName = config.getString("rabbit.exchangeName"),
		exchangeType = config.getString("rabbit.exchangeType"),
		durable      = config.getBoolean("rabbit.durable"),
		autoDelete   = config.getBoolean("rabbit.autoDelete"))

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
}
