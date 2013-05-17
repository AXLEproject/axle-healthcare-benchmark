/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.helper

import java.io.FileWriter

import eu.portavita.axle.Generator

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
