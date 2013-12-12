/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.generatable

import java.text.SimpleDateFormat
import java.util.Date
import scala.util.Random
import eu.portavita.axle.helper.DateTimes
import eu.portavita.axle.helper.RandomHelper
import eu.portavita.axle.model.PatientProfile
import eu.portavita.databus.data.model.PortavitaPatient
import eu.portavita.databus.data.model.Participation

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
    val person: Person,
    val roleId: Long,
	val organization: Organization,
	val fromTime: Date,
	val toTime: Date,
	val polisNumber: String,
	val treatments: List[Treatment],
	val careProvisionStart: Date) {

	val careProvisionId = Random.nextInt

	/**
	 * Returns a Java object for this patient.
	 *
	 * @return
	 */
	def toHl7CareProvision: eu.portavita.concept.CareProvision = {
		val patient = new eu.portavita.concept.Role
		patient.playerId = person.entityId.toString
		patient.scoperId = organization.id.toString
		val careProvision = new eu.portavita.concept.CareProvision
		careProvision.patient = patient
		careProvision.code = "170742000"
		careProvision.id = careProvisionId.toString
		careProvision
	}

	def toPortavitaPatient: PortavitaPatient = {
		val patient = new PortavitaPatient
		patient.setRoleId(roleId)
		patient.setFromTime(fromTime)
		patient.setToTime(toTime)
		patient.setOrganizationEntityId(organization.id)
	    patient.setPortavitaPerson(person.toPortavitaPerson)
		patient
	}

	def toParticipation(actId: Long, from: Date, to: Date, typeCode: String = "SBJ"): Participation = {
		val participation = new Participation()
		participation.setActId(actId)
		participation.setFromTime(from)
		participation.setToTime(to)
		participation.setRoleId(roleId)
		participation.setTypeCode(typeCode)
		participation
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

		val person = Person.sample(daysOld.toInt)
		val roleId = RoleId.next
		val birthDate = DateTimes.getRelativeDate((-1 * daysOld).toInt)
		val polisNumber = RandomHelper.alphanumeric(10)
		val pcprStart = DateTimes.getRelativeDate(daysOldAtStartPcpr.toInt, birthDate)
		val fromTime = pcprStart
		val principalPractitioner = RandomHelper.randomElement(organization.practitioners)
		val treatments = List(Treatment.sample(from = pcprStart, principalPractitioner = principalPractitioner))

		new Patient(person, roleId, organization, fromTime, null, polisNumber, treatments, pcprStart)
	}
}
