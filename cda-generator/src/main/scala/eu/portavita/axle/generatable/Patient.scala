/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generatable

import java.text.SimpleDateFormat
import java.util.Date
import scala.util.Random
import eu.portavita.axle.model.PatientProfile
import eu.portavita.axle.helper.DateTimes

/**
 * Represents a patient.
 *
 * @param organization Organization where the person is a patient.
 * @param entityId Entity id of the person.
 * @param name Name of the person.
 * @param birthDate Birth date of the person.
 * @param careProvisionStart Date of start of care provision.
 */
class Patient(
	val organization: Organization,
	override val entityId: Int,
	override val name: PersonName,
	override val birthDate: Date,
	val careProvisionStart: Date) extends Person(entityId, name, birthDate) {

	/**
	 * Returns a Java object for this patient.
	 *
	 * @return
	 */
	def toHl7Patient: eu.portavita.concept.Patient = {
		val patient = new eu.portavita.concept.Patient
		patient.entityId = entityId.toString
		patient
	}

	override def toString = {
		val formatter = new SimpleDateFormat("dd-MM-yyyy")
		super.toString + ", care provision started " + formatter.format(careProvisionStart) + "\n"
	}
}

object Patient {

	/**
	 * Creates a random patient.
	 *
	 * @param organization Organization where the person is a patient.
	 */
	def sample(patientProfile: PatientProfile, organization: Organization): Patient = {
		val ageAndPcpr = patientProfile.sampleAgeAndPcpr
		val daysOld = ageAndPcpr.get("DAYS_OLD_NOW").get.asInstanceOf[NumericObservation].value
		val daysOldAtStartPcpr = ageAndPcpr.get("DAYS_OLD_AT_START").get.asInstanceOf[NumericObservation].value

		val entityId = Random.nextInt
		val name: PersonName = PersonName.generate;
		val birthDate = DateTimes.getRelativeDate((-1 * daysOld).toInt)
		val pcprStart = DateTimes.getRelativeDate(daysOldAtStartPcpr.toInt, birthDate)
		new Patient(organization, entityId, name, birthDate, pcprStart)
	}
}
