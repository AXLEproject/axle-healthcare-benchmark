/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generatable

import java.util.Date
import java.util.regex.Matcher
import java.util.regex.Pattern

import eu.portavita.axle.GeneratorConfig
import eu.portavita.axle.helper.TerminologyDisplayNameProvider
import eu.portavita.databus.data.dto.ActDTO

/**
 * Represents a single observation event.
 */
abstract class Observation {

	val intervalRegex = Pattern.compile("^\\s*" +
		"(?<LEFT>\\d+([,\\.]\\d+)?)?" +
		"\\s*" +
		"(?<OPERATOR>-|<|>)?" +
		"\\s*" +
		"(?<RIGHT>\\d+([,\\.]\\d+)?)?" +
		"\\s*" +
		"[^\\s]*$")

	protected def extractInterval(value: String): (Option[Double], Option[Double]) = {
		def parseDouble(stringValue: String): Option[Double] = {
			if (stringValue == null || stringValue.isEmpty()) return None

			val valueCorrectFormat = stringValue.replaceAll(",", ".")
			try {
				Some(valueCorrectFormat.toDouble)
			} catch {
				case _: Throwable => None
			}
		}

		val m: Matcher = intervalRegex.matcher(value)
		if (m.matches()) {
			val operator = m.group("OPERATOR")
			val left = m.group("LEFT")
			val right = m.group("RIGHT")

			if ("-".equals(operator) || "<".equals(operator)) {
				return (parseDouble(left), parseDouble(right))
			} else if (">".equals(operator)) {
				return (parseDouble(right), parseDouble(left))
			} else if (operator == null || operator.isEmpty()) {
				if (left != null) {
					val parsedLeft = parseDouble(left)
					return (parsedLeft, parsedLeft)
				} else {
					val parsedRight = parseDouble(right)
					return (parsedRight, parsedRight)
				}
			}
		}

		(None, None)
	}

	/**
	 * Returns the act code of this observation.
	 *
	 * @return act code of observation
	 */
	def getCode: String

	/**
	 * Returns whether the observation has a value.
	 *
	 * @return whether the observation has a value
	 */
	def hasValue: Boolean

	/**
	 * Returns a Java object for this observation.
	 *
	 * @return Java object version of this observation
	 */
	def toHl7Act(date: Date): Option[ActDTO]

	def toReportString(displayNameProvider: TerminologyDisplayNameProvider): String
}

/**
 * Represents an observation with a numeric value.
 *
 * @param code Act code of the observation.
 * @param value Value of the observation.
 */
case class NumericObservation(val code: String, val value: Double, val unit: String) extends Observation {
	override def getCode = code
	override def hasValue = true

	override def toHl7Act(date: Date): Option[ActDTO] = {
		val act = new ActDTO
		act.setId(ActId.next)
		act.setCode(code)
		act.setClassCode("OBS")
		act.setMoodCode("EVN")
		act.setFromTime(date)
		act.setUnit(unit)
		act.setStatusCode("completed")
		if ("INT".equals(GeneratorConfig.valueTypeProvider.get(code))) {
			val roundedValue = Math.round(value)
			act.setValue(roundedValue.toString())
			act.setNumericValue1(roundedValue)
		} else {
			act.setValue(value.toString())
			act.setNumericValue1(value)
		}

		Some(act)
	}

	override def toString = "Num.Obs(" + code + ")=" + value

	override def toReportString(displayNameProvider: TerminologyDisplayNameProvider): String = {
		"observation %s was made and had outcome %s %s".format(displayNameProvider.get(code), value, unit)
	}
}

/**
 * Represents an observation with a discrete (coded) value.
 *
 * @param code Act code of the observation.
 * @param value Value of the observation.
 */
case class DiscreteObservation(val code: String, val value: String) extends Observation {
	override def getCode = code

	/**
	 * @return if the value is not an empty string nor "TRUE"
	 */
	override def hasValue = value.nonEmpty && !"TRUE".equals(value)

	override def toHl7Act(date: Date): Option[ActDTO] = {
		if (!hasValue) return None

		val act = new ActDTO
		act.setId(ActId.next)
		act.setCode(code)
		act.setClassCode("OBS")
		act.setMoodCode("EVN")
		act.setFromTime(date)
		act.setValue(value)
		act.setStatusCode("completed")

		if (code.equals("Portavita323") || code.equals("Portavita336") || code.equals("Portavita315") || code.equals("Portavita316")) {
			val (lower, upper) = extractInterval(value)
			if (lower.isDefined) act.setNumericValue1(lower.get)
			if (upper.isDefined) act.setNumericValue2(upper.get)
		}

		Some(act)
	}

	override def toString = code + "\t= " + value

	override def toReportString(displayNameProvider: TerminologyDisplayNameProvider): String = {
		"observation %s was made and had outcome %s".format(displayNameProvider.get(code), value)
	}
}
