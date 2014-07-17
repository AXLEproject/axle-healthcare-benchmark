package eu.portavita.axle.bayesiannetwork

import scala.annotation.tailrec
import eu.portavita.axle.generatable.NumericObservation
import eu.portavita.axle.generatable.Observation
import scala.util.Random

/**
 * Represents a single numeric variable in a Bayesian network.
 * @param code Act code of the variable.
 * @param parents Act codes of parent variables for this variable.
 * @param intercept
 * @param coefficients
 * @param standardDeviation
 */
class NumericVariable(
	val code: String,
	val unit: String,
	val parents: Set[String],
	val intercept: Double,
	val coefficients: Map[String, Double],
	val standardDeviation: Double) extends Variable {

	def sample(observedValues: Set[Observation]): Observation = {

		@tailrec
		def meanHelper(accum: Double, obs: Set[Observation]): Double = {
			if (obs.isEmpty) accum
			else {
				val numericObservation = obs.head.asInstanceOf[NumericObservation]
				val coefficient = coefficients.get(numericObservation.getCode).get
				meanHelper(coefficient * numericObservation.value + accum, obs.tail)
			}
		}

		def mean = meanHelper(intercept, observedValues)

		val value = standardDeviation * Random.nextGaussian() + mean
		new NumericObservation(code, value, unit)
	}

	override def toString(): String = {
		val s = StringBuilder.newBuilder

		s.append("Numeric variable with code " + code + "\n")
		s.append("Depends on: " + parents.mkString(", ") + "\n")
		s.append("Intercept = " + intercept + "\n")
		s.append("standardDeviation = " + standardDeviation + "\n")
		s.append("Coefficients: " + coefficients.mkString(", ") + "\n")

		s.toString
	}
}
