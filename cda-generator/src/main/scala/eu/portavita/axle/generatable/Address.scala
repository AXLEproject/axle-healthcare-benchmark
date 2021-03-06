package eu.portavita.axle.generatable

import java.util.Date

import scala.util.Random

import eu.portavita.axle.helper.DateTimes
import eu.portavita.axle.helper.RandomHelper
import eu.portavita.databus.data.dto.AddressDTO

class Address(
		val code: String,
		val city: String,
		val zipCode: String,
		val country: String,
		val validFrom: Date,
		val validTo: Date,
		val streetAddr1: String,
		val streetAddr2: String
		) {

	def toAddressDTO: AddressDTO = {
		val address = new AddressDTO
		address.setCode(code)
		address.setCityDescription(city)
		address.setStreetAddress1(streetAddr1)
		address.setStreetAddress2(streetAddr2)
		address.setValidFrom(validFrom)
		address.setValidTo(validTo)
		address.setZipCode(zipCode)
		address
	}
}

object Address {
	val minimalDaysOld = 30
	val maximalDaysOld = 20 * 365

	def sample(code: String): Address = {
		new Address(code = code,
				city = RandomHelper.string(RandomHelper.startingWithCapital, min=6, max=16),
				zipCode = "%4d".format(Random.nextInt(9999)) + RandomHelper.uppercase(2),
				country = RandomHelper.string(RandomHelper.startingWithCapital, min=8, max=16),
				validFrom = DateTimes.getRelativeDate(-RandomHelper.between(minimalDaysOld, maximalDaysOld)),
				validTo = null,
				streetAddr1 = RandomHelper.string(RandomHelper.startingWithCapital, min=10, max=24) + " " + Random.nextInt(1000),
				streetAddr2 = "")
	}
}
