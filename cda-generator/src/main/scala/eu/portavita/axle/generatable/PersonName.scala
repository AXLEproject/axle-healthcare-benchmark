/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generatable

import scala.util.Random
import eu.portavita.axle.helper.RandomHelper

/**
 * Represents a person name.
 *
 * @param firstName First name.
 * @param lastName Surname.
 * @param prefix Surname prefix.
 */
class PersonName(val givenName: String, val familyName: String, val prefix: String) {
	def hasPrefix = prefix.length > 0

	override def toString = {
		if (hasPrefix) givenName + " " + prefix + " " + familyName
		else givenName + " " + familyName
	}
}

object PersonName {
	/**
	 * Generates a random person name.
	 *
	 * @return
	 */
	def sample: PersonName = {
		new PersonName(
			givenName = RandomHelper.string(RandomHelper.startingWithCapital, min=4, max=8),
			familyName = RandomHelper.string(RandomHelper.startingWithCapital, min=6, max=14),
			prefix = if (Random.nextBoolean) RandomHelper.string(RandomHelper.lowercase, min=2, max=4) else ""
		)
	}
}
