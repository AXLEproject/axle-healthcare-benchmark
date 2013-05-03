/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.model

import scala.util.Random
import scala.annotation.tailrec

class MixtureModel (val components: Set[(Double, Gaussian)]) {

	def sample: Double = {
		val sampleSet =
			for ((weight, gaussian) <- components) yield weight * gaussian.sample

		sampleSet.sum
	}

/*
	private def chooseGaussian: Gaussian = {
		@tailrec
		def helper (r: Double, index: Integer): Gaussian = {
			require(weights.size > (index + 1))

			if (index == weights.size - 1)
				gaussians(index)
			else {
				val p = r - weights(index)
				if (p <= 0) gaussians(index)
				else helper(p, index + 1)
			}
		}

		helper(Random.nextDouble, 0)
	}
*/

}