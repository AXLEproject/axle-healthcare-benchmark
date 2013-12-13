/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generatable

import java.util.Date

import eu.portavita.axle.GeneratorConfig
import eu.portavita.databus.data.model.PortavitaAct

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
	def toHl7Act(date: Date): Option[PortavitaAct]
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

	override def toHl7Act(date: Date): Option[PortavitaAct] = {
		val act = new PortavitaAct
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

	override def toHl7Act(date: Date): Option[PortavitaAct] = {
		if (!hasValue) return None

		val act = new PortavitaAct
		act.setId(ActId.next)
		act.setCode(code)
		act.setClassCode("OBS")
		act.setMoodCode("EVN")
		act.setFromTime(date)
		act.setValue(value)
		act.setStatusCode("completed")

		Some(act)
	}

	override def toString = code + "\t= " + value
}
