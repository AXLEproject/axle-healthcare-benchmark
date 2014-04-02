/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generatable

import java.io.File
import java.util.ArrayList
import java.util.Date
import scala.annotation.tailrec
import scala.util.Random
import eu.portavita.axle.helper.DateTimes
import eu.portavita.axle.helper.RandomHelper
import eu.portavita.databus.data.model.PortavitaAddress
import eu.portavita.databus.data.model.PortavitaOrganization
import eu.portavita.axle.model.OrganizationModel

/**
 * Represents a healthcare organization.
 */
class Organization(
		val id: Long,
		val agbCode: String,
		val code: String,
		val name: String,
		val startDate: Date,
		val address: Address,
		val partOf: Option[Organization],
		val practitioners: List[Practitioner],
		val nrOfPatients: Int) {
	override def toString = "Organization '" + name + "' (started on " + startDate + ")"

	def toPortavitaOrganization: PortavitaOrganization = {
		val organization = new PortavitaOrganization
		val addresses = new ArrayList[PortavitaAddress]
		addresses.add(address.toPortavitaAddress)
		organization.setPortavitaAddresses(addresses)
		organization.setAgbCode(agbCode)
		organization.setCode(code)
		organization.setClassCode("ORG")
		organization.setEntityId(id)
		organization.setFromTime(startDate)
		organization.setEntityId(id)
		organization.setName(name)
		organization.setStatusCode("ACTIVE")
		if (partOf.isDefined) organization.setSuperOrganizationEntityId(partOf.get.id)

		organization
	}

	/**
	 * Returns the directory name for the given organization.
	 * @return relative directory path
	 */
	@tailrec
	final def getDirectoryFor(postfix: String = "", organization: Organization = this): String = {
		def addTo(organization: Organization, postfix: String): String = {
			if (postfix.isEmpty()) organization.fileName
			else organization.fileName + File.separator + postfix
		}
		organization.partOf match {
			case None => organization.fileName + File.separator + postfix
			case partOf: Option[Organization] => getDirectoryFor(addTo(organization, postfix), partOf.get)
		}
	}

	def fileName: String = "organization-" + id
	def directoryName: String = getDirectoryFor("", this)

}

object Organization {
	private val organizationCodes = List("HPRAK")
	val minimalDaysOld = 30
	val maximalDaysOld = 10 * 365

	/**
	 * Creates a random organization.
	 *
	 * @return
	 */
	def sample(model: OrganizationModel, partOf: Option[Organization]): Organization = {
		val id = EntityId.next
		val agb = Random.nextInt(99999999)
		val name = RandomHelper.string(RandomHelper.startingWithCapital, min=8, max=24)
		val startDate = DateTimes.getRelativeDate(RandomHelper.between(minimalDaysOld, maximalDaysOld))
		val code = organizationCodes(Random.nextInt(organizationCodes.length))
		val nrOfPatients = model.sampleNrOfPatients
		val nrOfPractitioners = Math.max(1, RandomHelper.between(0, nrOfPatients / 10))
		val practitioners = for (i <- 0 to nrOfPractitioners) yield Practitioner.sample(id)
		new Organization(id, "%08d".format(agb), code, name, startDate, Address.sample("WP"), partOf, practitioners.toList, nrOfPatients)
	}
}
