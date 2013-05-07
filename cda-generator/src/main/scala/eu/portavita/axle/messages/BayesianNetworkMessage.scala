/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.messages

import eu.portavita.axle.generatable.Examination
import eu.portavita.axle.generatable.Patient
import akka.actor.ActorRef
import java.util.Date

sealed trait BayesianNetworkMessage

/**
 * Message to request an examination for the given patient on the given date.
 */
case class ExaminationRequest (
		val patient: Patient,
		val date: Date
) extends BayesianNetworkMessage
