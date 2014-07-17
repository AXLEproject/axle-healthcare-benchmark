package eu.portavita.axle.bayesiannetwork

import org.scalatest.Matchers
import org.scalatest.FlatSpec
import scala.util.Random
import eu.portavita.axle.generatable.DiscreteObservation
import eu.portavita.axle.generatable.Observation
import eu.portavita.axle.generatable.DiscreteObservation

class DiscreteVariableSpec extends FlatSpec with Matchers {
	val seed = 1234
	val nrOfSamples = 1000

	val code = "the code"
	val codeOfParent = "the parent code"
	val valueCode1 = "this is a value"
	val valueCode2 = "this is another value"
	val valueOfParent1 = "this is the value of parent 1"
	val valueOfParent2 = "this is the value of parent 2"

	val probability1 = 0.8
	val probability2 = 0.2

	val observation1 = new DiscreteObservation(code, valueCode1)
	val observation2 = new DiscreteObservation(code, valueCode2)
	val parentObservation1 = new DiscreteObservation(codeOfParent, valueOfParent1)
	val parentObservation2 = new DiscreteObservation(codeOfParent, valueOfParent2)

	"A discrete variable" should "sample the correct value if it does not have any parents and one value" in {
		Random.setSeed(seed)

		val conditionalProbability = new ConditionalProbability(observation1, 1, Set[Observation]())

		val discreteVariable = new DiscreteVariable(code, conditionalProbs = Set(conditionalProbability), parents = Set())
		val sample = discreteVariable.sample(Set[Observation]())
		val discreteObservation = sample.asInstanceOf[DiscreteObservation]
		discreteObservation.value should be(valueCode1)
	}

	it should "sample the correct value if it does not have any parents and two values" in {
		Random.setSeed(seed)

		val conditionalProbability1 = new ConditionalProbability(observation1, 0.8, Set[Observation]())
		val conditionalProbability2 = new ConditionalProbability(observation2, 0.2, Set[Observation]())

		val discreteVariable = new DiscreteVariable(code,
			conditionalProbs = Set(conditionalProbability1, conditionalProbability2),
			parents = Set())
		val sample = discreteVariable.sample(Set[Observation]())
		val discreteObservation = sample.asInstanceOf[DiscreteObservation]
		discreteObservation.value should be(valueCode1)
	}

	it should "sample the correct distribution of values if it does not have any parents and two values" in {
		Random.setSeed(seed)

		val conditionalProbability1 = new ConditionalProbability(observation1, probability1, Set[Observation]())
		val conditionalProbability2 = new ConditionalProbability(observation2, probability2, Set[Observation]())

		val discreteVariable = new DiscreteVariable(code,
			conditionalProbs = Set(conditionalProbability1, conditionalProbability2),
			parents = Set())

		val results = sample(discreteVariable, Set())

		results.contains(valueCode1) should be(true)
		results.contains(valueCode2) should be(true)

		val nrOfVC1 = results.get(valueCode1).get
		val nrOfVC2 = results.get(valueCode2).get

		nrOfVC1 + nrOfVC2 should be(nrOfSamples)

		// Error margin should not be higher than 10%
		assert(probability1 * nrOfSamples - nrOfVC1 < nrOfSamples * 0.1)
		assert(probability2 * nrOfSamples - nrOfVC2 < nrOfSamples * 0.1)
	}

	it should "sample the correct distribution of values if it it has one parent" in {
		Random.setSeed(seed)

		val conditionalProbability1 = new ConditionalProbability(observation1, probability1, Set(parentObservation1))
		val conditionalProbability2 = new ConditionalProbability(observation2, probability2, Set(parentObservation1))

		val discreteVariable = new DiscreteVariable(code,
			conditionalProbs = Set(conditionalProbability1, conditionalProbability2),
			parents = Set(codeOfParent))

		val results = sample(discreteVariable, Set(parentObservation1))

		results.contains(valueCode1) should be(true)
		results.contains(valueCode2) should be(true)

		val nrOfVC1 = results.get(valueCode1).get
		val nrOfVC2 = results.get(valueCode2).get

		nrOfVC1 + nrOfVC2 should be(nrOfSamples)

		// Error margin should not be higher than 10%
		assert(probability1 * nrOfSamples - nrOfVC1 < nrOfSamples * 0.1)
		assert(probability2 * nrOfSamples - nrOfVC2 < nrOfSamples * 0.1)

	}

	private def sample(discreteVariable: DiscreteVariable, parentObservations: Set[Observation]): collection.mutable.Map[String, Int] = {
		val results = collection.mutable.Map[String, Int]()
		for (i <- 1 to nrOfSamples) {
			val sample = discreteVariable.sample(parentObservations).asInstanceOf[DiscreteObservation]
			val occurrences = results.getOrElse(sample.value, 0)
			results.update(sample.value, occurrences + 1)
		}
		results
	}
}