package eu.portavita.axle

import com.typesafe.config.ConfigFactory
import eu.portavita.terminology.LocalTerminologyCache

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
