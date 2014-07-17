/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.bayesiannetwork

import scala.annotation.tailrec
import scala.util.Random

import eu.portavita.axle.generatable.NumericObservation
import eu.portavita.axle.generatable.Observation

/**
 * Represents a single variable in a Bayesian network.
 */
trait Variable {

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




