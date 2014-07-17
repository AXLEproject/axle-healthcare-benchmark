package eu.portavita.axle.bayesiannetwork

import scala.util.Random
import org.scalatest.FlatSpec
import org.scalatest.Matchers
import eu.portavita.axle.generatable.NumericObservation
import eu.portavita.axle.generatable.Observation
import eu.portavita.axle.generatable.NumericObservation

class NumericVariableSpec extends FlatSpec with Matchers {
	val seed = 1234
	val nextGaussian = 0.14115907833078006
	val code = "some code"
	val unit = "some unit"
	val intercept = 1.4
	val standardDeviation = 1.6

	val parent1Code = "parent 1 code"
	val parent1Unit = "parent 1 unit"
	val parent1Coefficient = 1.7

	"A numeric variable" should "sample the correct value if it does not have any parents" in {
		Random.setSeed(seed)

		val coefficients: Map[String, Double] = Map.empty
		val nv = new NumericVariable(code, unit, Set.empty, intercept, coefficients, standardDeviation)

		val sample = nv.sample(Set.empty).asInstanceOf[NumericObservation]
		sample.value should be(intercept + standardDeviation * nextGaussian)
	}

	it should "sample the correct value if it has one parent" in {
		Random.setSeed(seed)

		val coefficients: Map[String, Double] = Map(parent1Code -> parent1Coefficient)
		val nv = new NumericVariable(code, unit, Set(parent1Code), intercept, coefficients, standardDeviation)

		val parentObservation = new NumericObservation(parent1Code, 4.2, parent1Unit)
		val sample = nv.sample(Set(parentObservation)).asInstanceOf[NumericObservation]
		sample.value should be(intercept + parent1Coefficient * parentObservation.value + standardDeviation * nextGaussian)
	}

	it should "sample the correct value if it has two parents" in {
		Random.setSeed(seed)

		val parent2Code = "parent 2 code"
		val parent2Unit = "parent 2 unit"
		val parent2Coefficient = 0.7

		val coefficients: Map[String, Double] = Map(parent1Code -> parent1Coefficient, parent2Code -> parent2Coefficient)
		val nv = new NumericVariable(code, unit, Set(parent1Code, parent2Code), intercept, coefficients, standardDeviation)

		val parent1Observation = new NumericObservation(parent1Code, 4.2, parent1Unit)
		val parent2Observation = new NumericObservation(parent2Code, 2.1, parent2Unit)
		val sample = nv.sample(Set(parent1Observation, parent2Observation)).asInstanceOf[NumericObservation]
		sample.value should be(intercept
			+ parent1Coefficient * parent1Observation.value
			+ parent2Coefficient * parent2Observation.value
			+ standardDeviation * nextGaussian)
	}

}