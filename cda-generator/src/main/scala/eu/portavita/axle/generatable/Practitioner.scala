/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generatable

import java.util.Date
import eu.portavita.axle.helper.DateTimes
import eu.portavita.axle.helper.RandomHelper
import eu.portavita.databus.data.model.PortavitaPractitioner
import eu.portavita.databus.data.model.PortavitaPerson
import eu.portavita.databus.data.model.PortavitaParticipation
import java.text.SimpleDateFormat

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

	def toParticipation(actId: Long, from: Date, to: Date = null, typeCode: String = "PRF"): PortavitaParticipation = {
		val participation = new PortavitaParticipation()
		participation.setActId(actId)
		participation.setFromTime(from)
		participation.setToTime(to)
		participation.setRoleId(roleId)
		participation.setTypeCode(typeCode)
		participation
	}

	override def toString = {
		"%s (in service from %s till %s)".format(person.name.toString(), DateTimes.dateFormat.format(fromTime), DateTimes.dateFormat.format(toTime))
	}

	def toReportString: String = {
		if (toTime != null) {
			return "%s (in service from %s till %s)".format(person.name.toString(), DateTimes.dateFormat.format(fromTime), DateTimes.dateFormat.format(toTime))
		}
		return "%s (in service from %s)".format(person.name.toString(), DateTimes.dateFormat.format(fromTime))
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
