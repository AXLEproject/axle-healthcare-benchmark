/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.helper

import java.io.FileWriter
import eu.portavita.axle.Generator
import java.io.File
import eu.portavita.axle.GeneratorConfig

/**
 * Utility class for writing marshalled clinical documents to file.
 */
class FilesWriter() {

	/**
	 * Helper instance for creating new file names.
	 */
	private val helper = new OutputHelper(GeneratorConfig.outputDirectory, "xml")

	/**
	 * Writes the given document to the next file.
	 * @param document Serialized document.
	 */
	def write(document: String): Unit = {
		FilesWriter.write(helper.nextFileName, document)
	}
}

object FilesWriter {
	/**
	 * Writes the given document to the next file.
	 * @param document Serialized document.
	 */
	def write(fileName: String, content: String): Unit = {
		val outputFile = new FileWriter(fileName)
		outputFile.write(content)
		outputFile.close()
	}

	def write(directoryPath: String, fileName: String, content: String): Unit = {
		val directoryFile = new File(directoryPath)
		if (!directoryFile.exists()) directoryFile.mkdirs()
		write(directoryPath + File.separator + fileName, content)
	}
}
