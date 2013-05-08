/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generatable

import scala.util.Random
import eu.portavita.axle.helper.RandomHelper

object PersonName {

	/**
	 * Generates a random person name.
	 *
	 * @return
	 */
	def generate: PersonName = {
		new PersonName(
			firstName = RandomHelper.string(4, 8),
			lastName = RandomHelper.string(6, 14),
			prefix = if (Random.nextBoolean) RandomHelper.string(2, 4) else ""
		)
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
