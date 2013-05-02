package eu.portavita.axle.helper

import java.io.File
import scala.annotation.tailrec
import java.util.UUID
import eu.portavita.axle.Generator

/**
 * Utility object for generating unique filenames.
 */
object OutputHelper {

	// Logger
	private val log = Generator.system.log
	private val messagePer = Generator.config.getInt("messagePer")

	// Unique prefix for all filenames.
	val filePrefix = UUID.randomUUID().toString()

	private var directoryNumber = 0;
	private val partitions = Generator.config.getInt("partitions")
	private var fileNumber = 0;

	/**
	 * Draws the next directory number.
	 * @return
	 */
	def getNextDirectoryNumber(): Int = {
		this.synchronized {
			directoryNumber += 1
			directoryNumber % partitions
		}
	}

	/**
	 * Draws the next file number.
	 * @return
	 */
	def getNextFileNumber(): Int = {
		this.synchronized {
			fileNumber += 1

			// Generate a log message every once in a while
			if (fileNumber % messagePer == 0)
				log.info("Generated %d CDAs.".format(fileNumber))


			fileNumber
		}
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
