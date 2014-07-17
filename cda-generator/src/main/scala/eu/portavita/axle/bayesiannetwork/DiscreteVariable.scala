package eu.portavita.axle.bayesiannetwork

import scala.annotation.tailrec
import eu.portavita.axle.generatable.Observation
import scala.util.Random

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
	private val givenMap: Map[Set[Observation], Set[ConditionalProbability]] = {
		val result = collection.mutable.Map[Set[Observation], Set[ConditionalProbability]]()
		for (cp <- conditionalProbs) {
			val currentSet = result.getOrElse(cp.given, Set())
			result.put(cp.given, currentSet + cp)
		}
		result.toMap
	}

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
