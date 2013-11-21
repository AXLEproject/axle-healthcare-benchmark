package eu.portavita.axle.helper

import scala.util.Random

/**
 * Collection of functions to make using random things easier.
 */
object RandomHelper {
	val alphabetLowerCase = "abcdefghijklmnopqrstuvwxyz"
	val alphabetUpperCase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	val alphabetAllCase = alphabetLowerCase + alphabetUpperCase

	/**
	 * Returns random string of alphanumeric characters of given length.
	 * @return
	 */
	def alphanumeric (length: Int): String =
		Random.alphanumeric take length mkString

	def randomString(alphabet: String)(length: Int): String = {
		Stream.continually(Random.nextInt(alphabet.size)).map(alphabet).take(length).mkString
	}

	def lowercase (length: Int): String = randomString(alphabetLowerCase)(length)
	def uppercase (length: Int): String = randomString(alphabetUpperCase)(length)
	def startingWithCapital (length: Int): String = randomString(alphabetUpperCase)(1) + randomString(alphabetLowerCase)(length - 1)
	def phrase (nrOfWords: Int, minWordLength: Int = 4, maxWordLength: Int = 12)(f: Int => String): String = {
		require(nrOfWords >= 0)
		val words = for(i <- 1 to nrOfWords) yield f(between(minWordLength,maxWordLength))
		words.mkString(" ")
	}

	def string(f: Int => String, min: Int, max: Int): String = f(between(min, max))

	/**
	 * Returns random string of alphanumeric characters with
	 * length in between given lengths.
	 *
	 * @param minLength
	 * @param maxLength
	 * @return
	 */
	def string (minLength: Int, maxLength: Int): String =
		alphanumeric(between(minLength, maxLength))

	/**
	 * Returns number in given interval. If min==max, then min is returned.
	 *
	 * @param min
	 * @param max
	 * @return
	 */
	def between (min: Int, max: Int): Int = {
		require(min <= max)
		if (min == max) min
		else min + Random.nextInt(max - min)
	}
}
