/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generatable

import java.util.Date
import scala.actors.threadpool.AtomicInteger
import scala.util.Random
import eu.portavita.databus.data.model.PortavitaOrganization
import eu.portavita.axle.helper.RandomHelper
import scala.annotation.tailrec
import java.io.File
import eu.portavita.axle.helper.DateTimes
import eu.portavita.databus.data.model.PortavitaAddress
import java.util.ArrayList

/**
 * Represents a healthcare organization.
 */
class Organization(
		val id: Int,
		val agbCode: String,
		val code: String,
		val name: String,
		val startDate: Date,
		val address: Address,
		val partOf: Option[Organization]) {
	override def toString = "Organization '" + name + "' (started on " + startDate + ")"

	def toPortavitaOrganization: PortavitaOrganization = {
		val organization = new PortavitaOrganization
		val portavitaAddress = new PortavitaAddress
		portavitaAddress.setCode(address.code)
		portavitaAddress.setCityDescription(address.city)
		portavitaAddress.setStreetAddress1(address.streetAddr1)
		portavitaAddress.setStreetAddress2(address.streetAddr2)
		portavitaAddress.setValidFrom(address.validFrom)
		portavitaAddress.setValidTo(address.validTo)
		portavitaAddress.setZipCode(address.zipCode)
		val addresses = new ArrayList[PortavitaAddress]
		addresses.add(portavitaAddress)
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
}

object Organization {
	private val idGenerator = new AtomicInteger(0)

	private val organizationCodes = List("HPRAK")
	val minimalDaysOld = 30
	val maximalDaysOld = 10 * 365
	val nrOfPractitioners = 31

	/**
	 * Creates a random organization.
	 *
	 * @return
	 */
	def sample(partOf: Option[Organization]): Organization = {
		val id = idGenerator.incrementAndGet()
		val agb = Random.nextInt(99999999)
		val name = RandomHelper.string(8, 24)
		val startDate = DateTimes.getRelativeDate(RandomHelper.between(minimalDaysOld, maximalDaysOld))
		val code = organizationCodes(Random.nextInt(organizationCodes.length))
<<<<<<< HEAD
		new Organization(id, "%08d".format(agb), code, name, startDate, Address.sample("WP"), partOf)
=======
		val practitioners = for (i <- 0 to nrOfPractitioners) yield Practitioner.sample(id)
		new Organization(id, "%08d".format(agb), code, name, startDate, Address.sample("WP"), partOf, practitioners.toList)
>>>>>>> fddbce6... fixup! Add FHIR organization message generator
	}
}
