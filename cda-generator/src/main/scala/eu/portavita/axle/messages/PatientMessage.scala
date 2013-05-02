package eu.portavita.axle.messages

import eu.portavita.axle.generatable.Organization
import eu.portavita.axle.generatable.Patient

sealed trait PatientMessage

case class PatientRequest(val organization: Organization) extends PatientMessage
