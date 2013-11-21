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
			firstName = RandomHelper.string(RandomHelper.startingWithCapital, min=4, max=8),
			lastName = RandomHelper.string(RandomHelper.startingWithCapital, min=6, max=14),
			prefix = if (Random.nextBoolean) RandomHelper.string(RandomHelper.lowercase, min=2, max=4) else ""
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
