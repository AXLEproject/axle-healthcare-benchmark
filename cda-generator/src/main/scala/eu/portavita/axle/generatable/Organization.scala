/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generatable

import java.util.Date
import scala.util.Random

/**
 * Represents a healthcare organization.
 *
 * @param name Name of the organization.
 * @param startDate TODO
 */
class Organization(val name: String, val startDate: Date) {
	override def toString = "Organization '" + name + "' (started on " + startDate + ")"
}

object Organization {

	/**
	 * Creates a random organization.
	 *
	 * @return
	 */
	def sample: Organization = {
		val name = Random.nextString(10)
		val startDate = new Date
		new Organization(name, startDate)
	}
}
