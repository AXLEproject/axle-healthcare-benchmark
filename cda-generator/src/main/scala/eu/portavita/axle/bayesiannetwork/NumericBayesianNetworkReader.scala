/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.bayesiannetwork

import scala.collection.mutable
import eu.portavita.axle.json.AsDouble
import eu.portavita.axle.json.AsMap
import eu.portavita.axle.Generator

/**
 * Contains functions to read Bayesian network of only numeric variables from JSON map.
 */
object NumericBayesianNetworkReader {

	/**
	 * Reads the numeric Bayesian network for the given examination from the given map.
	 * @param examinationCode Act code of the examination.
	 * @param variableMap Map encoding the network.
	 */
	def read(examinationName: String, variableMap: Map[String, Any]): BayesianNetwork = {
		// Read all variables from map
		val variables = for (
			AsMap(variables) <- List(variableMap);
			(jsonVariableName, variableProperties) <- variables;
			AsMap(propertyMap) = variableProperties;
			val cleanName = BayesianNetwork.clean(jsonVariableName)
		) yield cleanName -> readVariable(jsonVariableName, propertyMap)

		new BayesianNetwork(examinationName, variables.toMap)
	}

	/**
	 * Returns the discrete variable with the given name in JSON and the given properties.
	 *
	 * In JSON, child variables are encoded as follows:
	 *   <variable name>: {
	 *      "(Intercept)": double,
	 *      "sd": double,
	 *      <parent variable name>: double,
	 *      ...
	 *      <parent variable name>: double
	 *   }
	 */
	def readVariable(jsonName: String, properties: Map[String, Any]): NumericVariable = {
		// Get intercept and standard deviation
		val AsDouble(intercept) = properties.get("(Intercept)").get
		val AsDouble(standardDeviation) = properties.get("sd").get

		val parentProperties = properties - "(Intercept)" - "sd"

		val coefficients = mutable.Map[String, Double]()
		val parents = mutable.Set[String]()

		// Get the coefficients of all parents
		for (
			(jsonParentName, coefficientValue) <- parentProperties;
			AsDouble(coefficient) = coefficientValue;
			cleanParentName = BayesianNetwork.clean(jsonParentName)
		) {
			parents.add(cleanParentName)
			coefficients.put(cleanParentName, coefficient)
		}

		val code = BayesianNetwork.clean(jsonName)
		val unit = Generator.unitMap.getOrElse(code, "1")
		new NumericVariable(
			code,
			unit,
			parents.toSet,
			intercept,
			coefficients.toMap,
			standardDeviation)
	}
}
