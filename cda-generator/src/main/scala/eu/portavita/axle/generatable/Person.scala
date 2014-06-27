/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generatable

import java.util.Arrays
import java.util.Date

import scala.util.Random

import eu.portavita.axle.helper.DateTimes
import eu.portavita.axle.helper.RandomHelper
import eu.portavita.databus.data.dto.PersonDTO

/**
 * Represents a person.
 *
 * @param entityId Entity id of the person.
 * @param name Name of the person.
 * @param birthDate Birth date of the person.
 */
class Person(
	val entityId: Long,
	val name: PersonName,
	val birthDate: Date,
	val birthPlace: String,
	val bsn: String,
	val genderCode: String,
	val address: Address) {

	def toPortavitaPerson: PersonDTO = {
	    val portavitaPerson = new PersonDTO
	    portavitaPerson.setEntityId(entityId)
	    portavitaPerson.setAdministrativeGenderCode(genderCode)
	    portavitaPerson.setBirthPlace(birthPlace)
	    portavitaPerson.setBirthTime(birthDate)
	    portavitaPerson.setBsn(bsn)
	    portavitaPerson.setFamilyName(name.familyName)
	    portavitaPerson.setGivenName(name.givenName)
	    portavitaPerson.setFamilyNamePrefix(name.prefix)
	    portavitaPerson.setAddresses(Arrays.asList(address.toAddressDTO))
	    portavitaPerson.setName(name.toString())
	    portavitaPerson
	}
/*
	def toPortavitaPerson: PortavitaPerson = {
	    val portavitaPerson = new PortavitaPerson
	    portavitaPerson.setEntityId(entityId)
	    portavitaPerson.setAdministrativeGenderCode(genderCode)
	    portavitaPerson.setBirthPlace(birthPlace)
	    portavitaPerson.setBirthTime(birthDate)
	    portavitaPerson.setBsn(bsn)
	    portavitaPerson.setFamilyName(name.familyName)
	    portavitaPerson.setGivenName(name.givenName)
	    portavitaPerson.setFamilyNamePrefix(name.prefix)
	    portavitaPerson.setAddresses(Arrays.asList(address.toPortavitaAddress))
	    portavitaPerson.setName(name.toString())
	    portavitaPerson
	}
*/
	override def toString = {
		"%s (born at %s in %s)".format(name.toString(), DateTimes.dateFormat.format(birthDate), birthPlace)
	}

}

object Person {
	def sample: Person = {
		val daysOld = RandomHelper.between(10 * 365, 100 * 365)
		sample(daysOld)
	}

	def sample(daysOld: Int): Person = {
		val id = EntityId.next
		val name = PersonName.sample
		val birthDate = DateTimes.getRelativeDate((-1 * daysOld).toInt)
		val birthPlace = RandomHelper.startingWithCapital(RandomHelper.between(6, 14))
		val bsn = RandomHelper.numeric(9)
		val gender = if (Random.nextBoolean()) "M" else "F"
		val address = Address.sample("H")
		new Person(id, name, birthDate, birthPlace, bsn, gender, address)
	}
}
