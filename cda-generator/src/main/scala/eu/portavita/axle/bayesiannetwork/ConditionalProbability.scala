/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.bayesiannetwork
import scala.collection.mutable
import eu.portavita.axle.generatable.DiscreteObservation
import eu.portavita.axle.generatable.Observation

class ConditionalProbability (
		val observedValue: Observation,
		val probability: Double,
		// Set of observed values on which this conditional probability depends.
		val given: Set[Observation]
) {

	override def toString () = {
		val s = StringBuilder.newBuilder
		s.append("P(" + observedValue + " | ")
		s.append("\t" + given.mkString(", "))
		s.append(") = " + probability + "\n")
		s.toString
	}
}