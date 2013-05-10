/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.bayesiannetwork

import akka.actor.Actor
import akka.event.Logging
import eu.portavita.axle.messages.ExaminationRequest
import collection.mutable
import eu.portavita.axle.generatable.DiscreteObservation
import scala.util.parsing.json.JSON
import com.sun.xml.internal.bind.v2.runtime.unmarshaller.Discarder
import eu.portavita.axle.generatable.DiscreteObservation
import eu.portavita.axle.generatable.DiscreteObservation
import eu.portavita.axle.generatable.DiscreteObservation
import eu.portavita.axle.generatable.DiscreteObservation
import eu.portavita.axle.generatable.Observation
import java.util.HashMap

/**
 * Represents a Bayesian network.
 * @param name Name of the examination encoded in the network.
 * @param variables Map of act codes onto variables.
 */
class BayesianNetwork(
	val name: String,
	val variables: Map[String, Variable]) {

	def sample (evidence: Map[String, Observation]): Map[String, Observation] = {

		// Result map of observation values.
		val result = mutable.HashMap[String, Observation](evidence.toSeq: _*)

		/**
		 * Chooses an observation value for the variable with the given name. If that variable is dependent
		 * on other variables, resolves the parent variables first.
		 * @param code Act code of the observation to resolve.
		 * @return
		 */
		def resolveVariable(variableName: String): Observation = {
			val variable = variables.get(variableName).get
			val observedValues: Set[Observation] = {

				// Ensure all parents have an observation value.
				variable.parents.foreach(parent => getVariable(parent))

				// Get the values of the parents
				for (p <- variable.parents) yield result.get(p).get
			}

			// Sample a value for this variable.
			variable.sample(observedValues)
		}

		/**
		 * Returns the observation value of the variable with the given name.
		 * @param code Act code of the observation.
		 * @return
		 */
		def getVariable(variableName: String): Unit = {
			result.getOrElseUpdate(variableName, resolveVariable(variableName))
		}

		// Sample value for each variable.
		variables.keySet.foreach(variableName => getVariable(variableName))

		result.toMap
	}

	/**
	 * Samples a number of observations from this network.
	 * @return Map of act codes onto observations.
	 */
	def sample: Map[String, Observation] = sample(Map())

	override def toString() = {
		val s = StringBuilder.newBuilder
		variables.foreach(variable => s.append("For " + variable._1 + ":\n" + variable._2))
		s.toString
	}
}

object BayesianNetwork {
	private val PqPattern = "^pq_(.+)$".r
	private val CdPattern = "^cd_(.+)$".r
	private val NrExaminationsPattern = "^nr_of_(.+)$".r

	/**
	 * Cleans the given name.
	 * @param dirtyName
	 * @return Clean name
	 */
	def clean(dirtyName: String): String = {
		dirtyName match {
			case PqPattern(code) => restoreName(code)
			case CdPattern(code) => restoreName(code)
			case NrExaminationsPattern(code) => restoreName(code)

			case _ => dirtyName
		}
	}

	private def restoreName (name: String): String = name.replaceAll("\\.", "-")
}
