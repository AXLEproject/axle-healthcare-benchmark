package eu.portavita.axle.generatable

import scala.util.Random

object PersonName {

	/**
	 * Generates a random person name.
	 *
	 * @return
	 */
	def generate: PersonName = {
		val lengthFirst = 4 + Random.nextInt(4)
		val lengthLast = 6 + Random.nextInt(4)
		val first: String = Random.nextString(lengthFirst)
		val last: String = Random.nextString(lengthLast)
		val prefix: String = if (Random.nextBoolean) Random.nextString(3) else ""
		new PersonName(first, last, prefix)
	}
}

/**
 * Represents a person name.
 *
 * @param firstName First name.
 * @param lastName Surname.
 * @param prefix Surname prefix.
 */
class PersonName(firstName: String, lastName: String, prefix: String) {
	def hasPrefix = prefix.length > 0

	override def toString = {
		if (hasPrefix) firstName + " " + prefix + " " + lastName
		else firstName + " " + lastName
	}
}
