/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.model

import scala.util.Random

class Gaussian (val mean: Double, val standardDeviation: Double) {

	def sample: Double = {
		mean + Random.nextGaussian * standardDeviation
	}

}