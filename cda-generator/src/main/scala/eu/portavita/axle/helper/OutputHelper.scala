/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.helper

import java.io.File
import scala.annotation.tailrec
import java.util.UUID
import eu.portavita.axle.Generator
import scala.actors.threadpool.AtomicInteger
import eu.portavita.axle.GeneratorConfig

/**
 * Utility object for generating unique filenames.
 */
object OutputHelper {

	// Logger
	private val log = Generator.system.log
	private val messagePer = GeneratorConfig.config.getInt("messagePer")

	// Unique prefix for all filenames.
	val filePrefix = UUID.randomUUID().toString()

	private val partitions = GeneratorConfig.config.getInt("partitions")
	private var fileNumber: AtomicInteger = new AtomicInteger(0)
	private var directoryNumber: AtomicInteger = new AtomicInteger(0)

	// Whether there is a maximum number of CDAs to generate
	private val hasMaximumNumber = GeneratorConfig.cdasToGenerate > 0

	/**
	 * Draws the next directory number.
	 * @return next directory number
	 */
	def getNextDirectoryNumber(): Int = {
		directoryNumber.incrementAndGet()
	}

	/**
	 * Draws the next file number.
	 * @return next file number
	 */
	def getNextFileNumber(): Int = {
		val nextNumber = fileNumber.incrementAndGet()

		// Generate a log message every once in a while
		if (nextNumber % messagePer == 0)
			log.info("Generated %d CDAs.".format(nextNumber))

		// Stop application if there is a max number of CDAs to generate which has been exceeded
		if (hasMaximumNumber && nextNumber > GeneratorConfig.cdasToGenerate) {
			log.info("Generated all CDAs that I needed to generate")
			Generator.system.shutdown
		}

		nextNumber
	}
}

/**
 * Utility class for generating unique filenames.
 */
class OutputHelper(
	outputDirectory: String,
	extension: String) {

	/**
	 * String that can be used to easily format file names.
	 */
	private val fileNamePattern: String = "%s" + File.separator + "%s-%06d." + extension

	/**
	 * Returns full path of the next filename.
	 *
	 * @return
	 */
	def nextFileName: String = {
		val path = outputDirectory + File.separator + OutputHelper.getNextDirectoryNumber
		val directoryFile = new File(path)
		if (!directoryFile.exists()) {
			directoryFile.mkdirs()
		}
		fileNamePattern.format(path, OutputHelper.filePrefix, OutputHelper.getNextFileNumber)
	}
}
