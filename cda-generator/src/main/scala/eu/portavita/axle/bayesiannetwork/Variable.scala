/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.bayesiannetwork

import scala.annotation.tailrec
import scala.util.Random
import eu.portavita.axle.generatable.DiscreteObservation
import eu.portavita.axle.generatable.Observation
import eu.portavita.axle.generatable.NumericObservation
import eu.portavita.axle.generatable.NumericObservation

/**
 * Represents a single variable in a Bayesian network.
 */
abstract class Variable {

	/**
	 * Generates an observed value for the given variable.
	 * @param observedValues Set of observed values of independent variables on which this variable may
	 * depend.
	 * @return
	 */
	def sample(observedValues: Set[Observation]): Observation

	/**
	 * Returns the set of parent variables for this variable.
	 * @return
	 */
	def parents: Set[String]
}

/**
 * Represents a single discrete variable in a Bayesian network.
 * @param code Act code of the variable.
 * @param conditionalProbs Conditional probability matrix for this variable.
 * @param parents Act codes of parent variables for this variable.
 */
class DiscreteVariable(
	val code: String,
	val conditionalProbs: Set[ConditionalProbability],
	val parents: Set[String]) extends Variable {

	/**
	 * For better performance, map a set of observed values to the set of
	 * conditional probabilities with those observed values.
	 */
	private val givenMap: Map[Set[Observation], Set[ConditionalProbability]] =
		(for (cp <- conditionalProbs) yield (cp.given -> Set(cp))).toMap

	/**
	 * Generates a sample value for this variable using the given observed values of independent variables.
	 * @param observedValues Set of observed values of independent variables on which this variable may
	 * depend.
	 * @return
	 */
	def sample(observedValues: Set[Observation]): Observation = {

		@tailrec
		def helper(r: Double, probs: Set[ConditionalProbability]): Observation = {
			require(probs.size > 0)
			if (probs.size == 1) probs.head.observedValue
			else {
				val p = r - probs.head.probability
				if (p <= 0) probs.head.observedValue
				else helper(p, probs.tail)
			}
		}

		val probabilities = givenMap.get(observedValues).get
		val randomValue = Random.nextDouble

		helper(randomValue, probabilities)
	}

	/**
	 * Returns all conditional probabilities that match the given observed values.
	 * In other words, all P(x | observedValues).
	 * @param observedValues
	 * @return
	 */
	def getConditionalProbabilities(observedValues: Set[Observation]) = {
		conditionalProbs.filter(_.given.equals(observedValues))
	}

	override def toString() = {
		val s = StringBuilder.newBuilder
		s.append("Discrete variable with code " + code + "\n")
		s.append("Depends on: " + parents.mkString(", ") + "\n")
		conditionalProbs.foreach(cp => s.append(cp))
		s.append("\n\n")
		s.toString
	}
}

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
	val parents: Set[String],
	val intercept: Double,
	val coefficients: Map[String, Double],
	val standardDeviation: Double) extends Variable {

	def sample(observedValues: Set[Observation]): Observation = {

		@tailrec
		def goBananas(accum: Double, obs: List[Observation]): Double = {
			if (obs.isEmpty) accum
			else {
				val numericObservation = obs.head.asInstanceOf[NumericObservation]
				val observedValue = numericObservation.value
				val coefficient = coefficients.get(numericObservation.getCode).get
				goBananas(coefficient * observedValue + accum, obs.tail)
			}
		}

		var mean: Double = intercept

		for (observation <- observedValues) {
			val numericObservation = observation.asInstanceOf[NumericObservation]

			val observedValue = numericObservation.value
			val coefficient = coefficients.get(observation.getCode).get

			mean += coefficient * observedValue
		}

		val value = standardDeviation * Random.nextGaussian() + mean
		new NumericObservation(code, value)
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


