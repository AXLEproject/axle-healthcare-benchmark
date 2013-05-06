/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.model

import scala.util.parsing.json.JSON
import eu.portavita.axle.generatable.Organization
import scala.util.Random
import java.util.Date
import java.io.File
import eu.portavita.axle.json.AsMap
import eu.portavita.axle.json.AsDouble
import eu.portavita.axle.json.AsListOfDoubles

class OrganizationModel (
		val patientDistribution: MixtureModel,
		val employeeDistribution: MixtureModel
) {

	/**
	 * Returns a randomly generated number of patients (>=0) based
	 * on the distribution over the number of patients per organization.
	 */
	def sampleNrOfPatients: Integer = {
		math.max(0, patientDistribution.sample.toInt)
	}

	/**
	 * Returns a randomly generated number of employees (>=0) based
	 * on the distribution over the number of employees per organization.
	 */
	def sampleNrOfEmployees: Integer = {
		math.max(0, employeeDistribution.sample.toInt)
	}

}

object OrganizationModel {

	def read (modelsDirectory: String): OrganizationModel = {
		val organizationDirectory = modelsDirectory + File.separator + "organization"
		val patientModelFile = organizationDirectory + File.separator + "patientDistribution.json"
		val employeeModelFile = organizationDirectory + File.separator + "employeeDistribution.json"

		val patientJsonString = scala.io.Source.fromFile(patientModelFile).mkString
		val employeeJsonString = scala.io.Source.fromFile(employeeModelFile).mkString

		fromJson(patientJsonString, employeeJsonString)
	}


	def fromJson (patientJson: String, employeeJson: String): OrganizationModel = {

		val Some(AsMap(jsonPatientMixtureModel)) = JSON.parseFull(patientJson)
		val patientDistribution = readMixtureModel(jsonPatientMixtureModel)

		val Some(AsMap(jsonEmployeeMixtureModel)) = JSON.parseFull(employeeJson)
		val employeeDistribution = readMixtureModel(jsonEmployeeMixtureModel)

		new OrganizationModel(patientDistribution, employeeDistribution)
	}

	def readMixtureModel (jsonMixtureModel: Map[String, Any]): MixtureModel = {
		val AsListOfDoubles(mean)    = jsonMixtureModel.get("mean").get
		val AsListOfDoubles(sigma)   = jsonMixtureModel.get("sigma").get
		val AsListOfDoubles(weights) = jsonMixtureModel.get("weight").get

		assert(mean.size == sigma.size && sigma.size == weights.size)

		val components =
			for (index <- 0 until mean.size)
				yield (weights(index), new Gaussian(mean(index), sigma(index)))

		new MixtureModel(components.toSet)
	}
}