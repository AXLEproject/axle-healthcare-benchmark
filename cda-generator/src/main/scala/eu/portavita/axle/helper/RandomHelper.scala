package eu.portavita.axle.helper

import scala.util.Random

/**
 * Collection of functions to make using random things easier.
 */
object RandomHelper {
	/**
	 * Returns random string of alphanumeric characters of given length.
	 * @return
	 */
	def string (length: Int): String =
		Random.alphanumeric take length mkString

	/**
	 * Returns random string of alphanumeric characters with
	 * length in between given lengths.
	 *
	 * @param minLength
	 * @param maxLength
	 * @return
	 */
	def string (minLength: Int, maxLength: Int): String =
		string(between(minLength, maxLength))

	/**
	 * Returns number in given interval.
	 *
	 * @param min
	 * @param max
	 * @return
	 */
	def between (min: Int, max: Int): Int = {
		require(min <= max)
		min + Random.nextInt(max - min)
	}
}