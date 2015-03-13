/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generatable

import java.io.File
import java.util.ArrayList
import java.util.Date
import scala.annotation.tailrec
import scala.util.Random
import eu.portavita.axle.GeneratorConfig
import eu.portavita.axle.helper.DateTimes
import eu.portavita.axle.helper.RandomHelper
import eu.portavita.axle.model.OrganizationModel
import eu.portavita.databus.data.dto.OrganizationDTO
import eu.portavita.databus.data.dto.AddressDTO

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
		val careGroupEmployees: List[Practitioner],
		val researchers: List[Practitioner],
		val nrOfPatients: Int) {
	override def toString = "Organization '" + name + "' (started on " + startDate + ")"

	def toOrganizationDTO: OrganizationDTO = {
		val organization = new OrganizationDTO
		val addresses = new ArrayList[AddressDTO]
		addresses.add(address.toAddressDTO)
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
	private val organizationCodes = List(("HPRAK", 0.8), ("APTK", 0.1), ("ZI", 0.08), ("HOSP", 0.02))
	val minimalDaysOld = 30
	val maximalDaysOld = 10 * 365

	def sample(model: OrganizationModel, partOf: Organization): Organization = {
		val id = EntityId.next
		val agb = Random.nextInt(99999999)
		val name = RandomHelper.string(RandomHelper.startingWithCapital, min=8, max=24)
		val startDate = DateTimes.getRelativeDate(RandomHelper.between(minimalDaysOld, maximalDaysOld))
		val code = randomOrganizationCode()
		val nrOfPatients = model.sampleNrOfPatients * GeneratorConfig.patientsPerOrganizationRatio
		val nrOfPractitioners = Math.max(1, RandomHelper.between(0, nrOfPatients / 10))
		val practitioners = for (i <- 0 to nrOfPractitioners) yield Practitioner.sample(id)
		val careGroupEmployees = List[Practitioner]()
		new Organization(id, "%08d".format(agb), code, name, startDate, Address.sample("WP"), Some(partOf), practitioners.toList, careGroupEmployees, Nil, nrOfPatients)
	}

	def sampleCareGroup: Organization = {
		val id = EntityId.next
		val agb = Random.nextInt(99999999)
		val name = RandomHelper.string(RandomHelper.startingWithCapital, min=8, max=24)
		val startDate = DateTimes.getRelativeDate(RandomHelper.between(minimalDaysOld, maximalDaysOld))
		val code = "CAREGROUP"
		val nrOfPatients = 0
		val nrOfCareGroupEmployees = Math.max(1, RandomHelper.between(0, 12))
		val careGroupEmployees = for (i <- 0 to nrOfCareGroupEmployees) yield Practitioner.sampleCareGroupEmployee(id)
		val nrOfResearchers = Math.max(1, RandomHelper.between(0, 4))
		val researchers = for (i <- 0 to nrOfResearchers) yield Practitioner.sampleResearcher(id)
		new Organization(id, "%08d".format(agb), code, name, startDate, Address.sample("WP"), None, Nil, careGroupEmployees.toList, researchers.toList, nrOfPatients)
	}

	private def randomOrganizationCode(): String = {
		organizationCodes.foreach(e => {
			if (Random.nextDouble() < e._2) {
				return e._1
			}
		})

		return organizationCodes(Random.nextInt(organizationCodes.length))._1
	}
}
