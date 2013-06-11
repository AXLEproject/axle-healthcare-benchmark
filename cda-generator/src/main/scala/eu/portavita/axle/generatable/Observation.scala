/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generatable

import scala.util.Random
import eu.portavita.terminology.CodeSystem
import java.util.Date
import eu.portavita.concept.Act

/**
 * Represents a single observation event.
 */
abstract class Observation {

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
	def toHl7Act: Option[eu.portavita.concept.Act]
}

/**
 * Represents an observation with a numeric value.
 *
 * @param code Act code of the observation.
 * @param value Value of the observation.
 */
case class NumericObservation(val code: String, val value: Double) extends Observation {
	override def getCode = code
	override def hasValue = true

	override def toHl7Act: Option[eu.portavita.concept.Act] = {
		val act = new Act
		act.code = code
		act.codeSystem = CodeSystem.guess(act.code)
		act.classCode = "OBS"
		act.moodCode = "EVN"
		act.value = value.toString
		act.numericValue1 = value.toString

		Some(act)
	}

	override def toString = "Num.Obs(" + code + ")=" + value
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
	override def hasValue = value.nonEmpty && !value.equals("TRUE")

	override def toHl7Act: Option[eu.portavita.concept.Act] = {
		if (!hasValue) return None

		val act = new Act
		act.code = code
		act.codeSystem = CodeSystem.guess(act.code)
		act.classCode = "OBS"
		act.moodCode = "EVN"
		act.value = value

		Some(act)
	}

	override def toString = code + "\t= " + value
}
