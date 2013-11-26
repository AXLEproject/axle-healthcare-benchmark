/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generatable

import java.util.Date
import eu.portavita.axle.helper.DateTimes
import eu.portavita.axle.helper.RandomHelper
import eu.portavita.databus.data.model.PortavitaPractitioner
import eu.portavita.databus.data.model.PortavitaPerson

/**
 * Represents a health care practitioner.
 */
class Practitioner(
	val roleId: Long,
	val person: Person,
	val fromTime: Date,
	val toTime: Date,
	val organizationEntityId: Long) {

  def toPortavitaEmployee: PortavitaPractitioner = {
    val practitioner = new PortavitaPractitioner
    practitioner.setRoleId(roleId)
    practitioner.setFromTime(fromTime)
    practitioner.setToTime(toTime)
    practitioner.setOrganizationEntityId(organizationEntityId)
    practitioner.setPortavitaPerson(person.toPortavitaPerson)
    practitioner
  }
}

object Practitioner {
	def sample(id: Long): Practitioner = {
		val roleId = RoleId.next
		val person = Person.sample
		val fromTime = DateTimes.getRelativeDate(RandomHelper.between(-10 * 365, 0), new Date)
		new Practitioner(roleId, person, fromTime, null, id)
	}
}
