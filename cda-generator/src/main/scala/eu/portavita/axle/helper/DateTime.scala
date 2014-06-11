/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.helper

import java.util.Calendar
import java.util.Date
import org.apache.commons.lang3.time.FastDateFormat
import org.apache.commons.lang3.time.FastDateParser
import java.text.SimpleDateFormat
import eu.portavita.axle.GeneratorConfig

object DateTimes {
	val dateParser = new SimpleDateFormat("yyyy-MM-dd")
	val todayDate = dateParser.parse(GeneratorConfig.todayDateString)
	val dateFormat = FastDateFormat.getInstance("yyyy-MM-dd")

	/**
	 * Returns the date as the given number of days after the given date.
	 *
	 * @param days Number of days.
	 * @param date
	 * @return
	 */
	def getRelativeDate (days: Int, date: Date = todayDate): Date = {
		val cal = Calendar.getInstance()
		cal.setTime(date)
		cal.add(Calendar.DATE, days)
		return cal.getTime()
	}


	/**
	 * Returns the age in years of the person born on the given date.
	 *
	 * @param birthDate Person's birth date
	 * @return
	 */
	def age (birthDate: Date): Int = {
		todayDate.getYear() - birthDate.getYear()
	}
}
