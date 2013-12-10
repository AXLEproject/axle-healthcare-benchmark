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
	/** @see <a href="http://nl.wikipedia.org/wiki/Tussenvoegsel">List of prefixes in the Netherlands</a> */
	val prefixes = List(
		"af", "aan", "bij", "de", "den", "der", "d'", "het", "'t", "in", "onder", "op", "over", "'s", "'t", "te", "ten", "ter", "tot", "uit", "uijt",
		"van", "vanden", "ver", "voor", "aan de", "aan den", "aan der", "aan het", "aan 't", "bij de", "bij den", "bij het", "bij 't", "boven d'",
		"de die", "de die le", "de l'", "de la", "de las", "de le", "de van der", "in de", "in den", "in der", "in het", "in 't", "onder de", "onder den",
		"onder het", "onder 't", "over de", "over den", "over het", "over 't", "op de", "op den", "op der", "op gen", "op het", "op 't", "op ten", "van de",
		"van de l'", "van den", "van der", "van gen", "van het", "van la", "van 't", "van ter", "van van de", "uit de", "uit den", "uit het", "uit 't",
		"uit te de ", "uit ten", "uijt de", "uijt den", "uijt het", "uijt 't", "uijt te de ", "uijt ten", "voor de", "voor den", "voor in 't", "a", "al",
		"am", "auf", "aus", "ben", "bin", "da", "dal", "dalla", "della", "das", "die", "den", "der", "des", "deca", "degli", "dei", "del", "di", "do", "don",
		"dos", "du", "el", "i", "im", "L", "la", "las", "le", "les", "lo", "los", "tho", "thoe", "thor", "to", "toe", "unter", "vom", "von", "vor", "zu", "zum",
		"zur", "am de", "auf dem", "auf den", "auf der", "auf ter", "aus dem", "aus den", "aus der", "aus 'm", "die le", "von dem", "von den", "von der", "von 't",
		"vor der")

	/**
	 * Generates a random person name.
	 *
	 * @return
	 */
	def sample: PersonName = {
		new PersonName(
			givenName = RandomHelper.string(RandomHelper.startingWithCapital, min = 4, max = 8),
			familyName = RandomHelper.string(RandomHelper.startingWithCapital, min = 6, max = 14),
			prefix = if (Random.nextBoolean) RandomHelper.randomElement(prefixes) else "")
	}
}
