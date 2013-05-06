/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.model

import java.io.File
import scala.util.parsing.json.JSON
import eu.portavita.axle.bayesiannetwork.BayesianNetwork
import eu.portavita.axle.bayesiannetwork.NumericBayesianNetworkReader
import eu.portavita.axle.generatable.NumericObservation
import eu.portavita.axle.generatable.Patient
import eu.portavita.axle.helper.DateTimes
import eu.portavita.axle.json.AsMap
import eu.portavita.axle.generatable.Observation
import eu.portavita.axle.generatable.NumericObservation
import java.util.Date
import scala.util.Random

class PatientProfile(
	examinationDistribution: BayesianNetwork,
	ageAndPcprDisctribution: BayesianNetwork) {

	/**
	 * Returns a mapping from several properties to their sampled values.
	 * @return
	 */
	def sampleAgeAndPcpr = ageAndPcprDisctribution.sample

	/**
	 * Returns a map from multiple ages of the given patient and a map from examination
	 * code and the number of times that examination should be performed in this age.
	 * @return
	 */
	def sampleExaminations(patient: Patient): Map[Int, Map[String, Int]] = {
		// Patient's age at the end of care provision
		val ageAtEnd = DateTimes.age(patient.birthDate)

		// Patient's age at the beginning of the care provision
		val ageAtStart = ageAtEnd - DateTimes.age(patient.careProvisionStart)

		// For each age of the patient during his care provision
		(for (age <- ageAtStart to ageAtEnd)
			yield (age, sampleExaminations(age))
		) toMap
	}

	/**
	 * Returns a map from examination code to the number of examinations that should be
	 * performed during the given age of the patient.
	 *
	 * @return
	 */
	def sampleExaminations(age: Int): Map[String, Int] = {
		// Set person age to the given age, so that this age is used instead of being sampled
		val evidence = Map("PERSON_AGE" -> NumericObservation("PERSON_AGE", age.toDouble))

		for {
			(examinationCode, sampledObservation) <- examinationDistribution.sample(evidence)

			// Ignore person age because it's not an examination
			if (!"PERSON_AGE".equals(examinationCode))

			// To get the sampled value, cast observation to numeric observation
			val sampledValue = sampledObservation.asInstanceOf[NumericObservation].value

		} yield {
			(examinationCode, math.round(sampledValue).toInt)
		}
	}
}

object PatientProfile {
	def read(modelsDirectory: String): PatientProfile = {

		val examinationDistribution = networkFor("nrOfExaminations", modelsDirectory)
		val ageAndPcprDisctribution = networkFor("ageAndPcprDisctribution", modelsDirectory)

		new PatientProfile(examinationDistribution.get, ageAndPcprDisctribution.get)
	}

	def networkFor(name: String, modelsDirectory: String): Option[BayesianNetwork] = {

		val examinationsFileName = modelsDirectory + File.separator + "patient" + File.separator + name + ".json"
		val examinationsJsonString = scala.io.Source.fromFile(examinationsFileName).mkString

		val parsedJson = JSON.parseFull(examinationsJsonString)
		if (parsedJson.isEmpty) throw new IllegalArgumentException("Unable to parse JSON for " + name)

		val Some(AsMap(main)) = parsedJson

		val numericNetwork =
			try {
				// Try to read the network for the numeric observations
				val numericJson = main.get("numeric")
				val AsMap(numeric) = numericJson.get
				val AsMap(network) = numeric.get("network").get

				Some(NumericBayesianNetworkReader.read(name, network))
			} catch {
				case e: Throwable => None
			}

		numericNetwork
	}
}