/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generatable

import java.util.Date
import java.text.SimpleDateFormat

/**
 * Represents a person.
 *
 * @param entityId Entity id of the person.
 * @param name Name of the person.
 * @param birthDate Birth date of the person.
 */
class Person(
	val entityId: Int,
	val name: PersonName,
	val birthDate: Date) {

	override def toString = {
		val s = StringBuilder.newBuilder
		val formatter = new SimpleDateFormat("dd-MM-yyyy")
		s.append("Patient " + name +
			", birth date = " + formatter.format(birthDate) + "\n")
		s.toString
	}
}
