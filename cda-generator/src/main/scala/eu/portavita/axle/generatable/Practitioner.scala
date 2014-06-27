/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generatable

import java.util.Date

import scala.collection.JavaConversions._

import eu.portavita.axle.helper.DateTimes
import eu.portavita.axle.helper.RandomHelper
import eu.portavita.databus.data.dto.ParticipationDTO
import eu.portavita.databus.data.dto.PractitionerDTO

/**
 * Represents a health care practitioner.
 */
class Practitioner(
	val roleId: Long,
	val person: Person,
	val fromTime: Date,
	val toTime: Date,
	val organizationRoles: List[String],
	val organizationEntityId: Long) {

	def toPortavitaEmployee: PractitionerDTO = {
		val practitioner = new PractitionerDTO
		practitioner.setRoleId(roleId)
		practitioner.setFromTime(fromTime)
		practitioner.setToTime(toTime)
		practitioner.setOrganizationEntityId(organizationEntityId)
		practitioner.setPortavitaPerson(person.toPortavitaPerson)
		practitioner.setOrganizationRoleCodes(organizationRoles)
		practitioner
	}

	def toParticipation(actId: Long, from: Date, to: Date = null, typeCode: String = "PRF"): ParticipationDTO = {
		val participation = new ParticipationDTO()
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
	def sample(organizationEntityId: Long): Practitioner = {
		val roleId = RoleId.next
		val person = Person.sample
		val fromTime = DateTimes.getRelativeDate(RandomHelper.between(-10 * 365, 0), new Date)
		val organizationRoles = List("309389004") // medical practitioner grade
		new Practitioner(roleId, person, fromTime, null, organizationRoles, organizationEntityId)
	}

	def sampleCareGroupEmployee(organizationEntityId: Long): Practitioner = {
		val roleId = RoleId.next
		val person = Person.sample
		val fromTime = DateTimes.getRelativeDate(RandomHelper.between(-10 * 365, 0), new Date)
		val organizationRoles = List("6868009") // hospital administrator
		new Practitioner(roleId, person, fromTime, null, organizationRoles, organizationEntityId)
	}

	def sampleResearcher(organizationEntityId: Long): Practitioner = {
		val roleId = RoleId.next
		val person = Person.sample
		val fromTime = DateTimes.getRelativeDate(RandomHelper.between(-10 * 365, 0), new Date)
		val organizationRoles = List("309397006") // research fellow
		new Practitioner(roleId, person, fromTime, null, organizationRoles, organizationEntityId)
	}
}
