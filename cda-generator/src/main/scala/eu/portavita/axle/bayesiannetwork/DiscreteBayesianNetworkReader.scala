/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.bayesiannetwork

import scala.collection.mutable
import eu.portavita.axle.generatable.DiscreteObservation
import eu.portavita.axle.json.AsMap
import eu.portavita.axle.json.AsListOfDoubles
import eu.portavita.axle.json.AsListOfStrings

/**
 * Contains functions to read Bayesian network of only discrete variables from JSON map.
 */
object DiscreteBayesianNetworkReader {

	/**
	 * Reads the discrete Bayesian network for the given examination from the given map.
	 * @param examinationCode Act code of the examination.
	 * @param variableMap Map encoding the network.
	 */
	def read(examinationCode: String, variableMap: Map[String, Any]): BayesianNetwork = {
		val variables = mutable.Map[String, DiscreteVariable]()
		for (
			AsMap(propertyMap) <- List(variableMap);
			(jsonVariableName, jsonVariableProperties) <- propertyMap;
			AsMap(variableProperties) = jsonVariableProperties;
			cleanName = BayesianNetwork.clean(jsonVariableName)
		) {
			variables.put(cleanName,
				// It is a root variable if it contains a key "Var1"
				if (variableProperties.contains("Var1")) {
					readRootVariable(jsonVariableName, variableProperties)
				} else {
					readChildVariable(jsonVariableName, variableProperties)
				}
			)
		}
		new BayesianNetwork(examinationCode, variables.toMap)
	}

	/**
	 * Returns the discrete variable with the given name in JSON and the given properties.
	 *
	 * In JSON, child variables are encoded as follows:
	 *   <variable name>: {
	 *      <parent variable name>: [ ... variable values ... ],
	 *      ...
	 *      <parent variable name>: [ ... variable values ... ],
	 *      "Freq": [ ... probabilities ... ]
	 *   }
	 */
	def readChildVariable(jsonName: String, properties: Map[String, Any]): DiscreteVariable = {
		val cleanName = BayesianNetwork.clean(jsonName)
		// Get probabilities from map
		val AsListOfDoubles(probabilities) = properties.get("Freq").get

		// Get values for this node
		val AsListOfStrings(nodeValues) = properties.get(jsonName).get
		val currentNode = nodeValues.map(v => DiscreteObservation(cleanName, v))

		require(probabilities.length == currentNode.length)

		// Get properties of all parents
		val parents = properties - "Freq" - jsonName

		// Map parent name to list of values
		val observations = mutable.Map[String, List[DiscreteObservation]]()
		for (
			(jsonName, jsonValue) <- parents;
			AsListOfStrings(parentValues) = jsonValue; // Convert JSON value to a list of strings
			parentName = BayesianNetwork.clean(jsonName) // Clean the name used by JSON
		) {
			// Construct a list of discrete observations from values
			val toAdd = parentValues.map(v => DiscreteObservation(parentName, v))

			// Add it to the list of observations
			observations.put(parentName, toAdd)
		}

		// Construct all conditional probabilities on which this variable depends
		val cps = for (i <- 0 until probabilities.length) yield {
			// All observations on which this probability depends
			val observedValues = for ((obsName, observationList) <- observations) yield observationList(i)

			new ConditionalProbability(currentNode(i), probabilities(i), observedValues.toSet)
		}

		val nodeParents = observations.keySet

		new DiscreteVariable(cleanName, cps.toSet, nodeParents.toSet)
	}

	/**
	 * Returns a discrete variable that has no parents that has the given name
	 * in JSON and the given properties.
	 *
	 * In JSON, such a variable is encoded as:
	 *
	 *   <root variable name>: {
	 *      "Var1" : [ ... root variable values ... ],
	 *      "Freq" : [ ... probabilities of values ... ]
	 *   }
	 */
	def readRootVariable(jsonName: String, properties: Map[String, Any]): DiscreteVariable = {
		val cleanName = BayesianNetwork.clean(jsonName)

		// Get node values and their prior probabilities
		val AsListOfStrings(nodeValues) = properties.get("Var1").get
		val AsListOfDoubles(probabilities) = properties.get("Freq").get

		// Every node values must have a probability
		require(nodeValues.length == probabilities.length)

		// Extract all possible values
		val observations = nodeValues.map(v => DiscreteObservation(cleanName, v))

		// Extract (conditional) probabilities
		val cps =
			for (i <- 0 until probabilities.length) yield new ConditionalProbability(observations(i), probabilities(i), Set())

		// Return instantiated variable
		new DiscreteVariable(cleanName, cps.toSet, Set())
	}
}
