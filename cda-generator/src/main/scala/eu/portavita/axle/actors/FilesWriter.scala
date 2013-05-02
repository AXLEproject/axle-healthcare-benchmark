package eu.portavita.axle.actors

import java.io.FileWriter

import akka.actor.Actor
import akka.actor.ActorLogging
import eu.portavita.axle.Generator
import eu.portavita.axle.helper.OutputHelper
import eu.portavita.axle.messages.MarshalledDocument

/**
 * Utility class for writing marshalled clinical documents to file.
 */
class FilesWriter() {

	/**
	 * Helper instance for creating new file names.
	 */
	private val helper = new OutputHelper(
		Generator.outputDirectory, "xml")

	/**
	 * Writes the given document to the next file.
	 * @param document Serialized document.
	 */
	def write(document: String): Unit = {
		val outputFile = new FileWriter(helper.nextFileName)
		outputFile.write(document.toString())
		outputFile.close()
	}
}
