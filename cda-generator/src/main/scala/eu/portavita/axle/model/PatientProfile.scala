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

/**
 * Class with a profile of patients describing the patient's age, care provision, and
 * what examinations are performed.
 *
 * @param examinationDistribution Bayesian network describing how many examinations are performed during a certain age of the patient
 * @param ageAndPcprDisctribution Bayesian network describing the patient's age and his care provision
 */
class PatientProfile(
	examinationDistribution: BayesianNetwork,
	ageAndPcprDisctribution: BayesianNetwork) {

	/**
	 * Returns a mapping from several properties to their sampled values.
	 * @return
	 */
	def sampleAgeAndPcpr = ageAndPcprDisctribution.sample

	/**
	 * Returns a map from multiple ages of the given patient onto a map from examination
	 * code onto the number of times that examination should be performed in this age.
	 * @return
	 */
	def sampleExaminations(patient: Patient): Map[Int, Map[String, Int]] = {
		val ageAtEnd = DateTimes.age(patient.birthDate)
		val ageAtStart = ageAtEnd - DateTimes.age(patient.careProvisionStart)
		(for (age <- ageAtStart to ageAtEnd)
			yield (age, sampleExaminations(age))) toMap
	}

	/**
	 * Returns a map from examination code onto the number of examinations that should be
	 * performed during the given age of the patient.
	 * @return
	 */
	def sampleExaminations(age: Int): Map[String, Int] = {

		// Set person age to the given age, so that this age is used instead of being sampled
		val evidence = Map("PERSON_AGE" -> NumericObservation("PERSON_AGE", age.toDouble))

		// Sample distributions of numbers of examinations.
		for {
			(examinationCode, sampledObservation) <- examinationDistribution.sample(evidence)
			if (!"PERSON_AGE".equals(examinationCode))
			val sampledValue = sampledObservation.asInstanceOf[NumericObservation].value
		} yield {
			(examinationCode, math.round(sampledValue).toInt)
		}
	}
}

/**
 * Functions to load patient profiles.
 */
object PatientProfile {
	/**
	 * Returns a patient profile that was instantiated from the model files in
	 * the given directory.
	 * @return
	 */
	def read(modelsDirectory: String): PatientProfile = {

		val examinationDistribution = networkFor("nrOfExaminations", modelsDirectory)
		val ageAndPcprDisctribution = networkFor("ageAndPcprDisctribution", modelsDirectory)

		new PatientProfile(examinationDistribution.get, ageAndPcprDisctribution.get)
	}

	/**
	 * Returns the optional Bayesian network for the model with the given name
	 * in the given directory.
	 * @return
	 */
	private def networkFor(name: String, modelsDirectory: String): Option[BayesianNetwork] = {

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