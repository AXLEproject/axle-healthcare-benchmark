/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.messages

import eu.portavita.axle.generatable.Examination
import eu.portavita.axle.generatable.Patient
import akka.actor.ActorRef
import java.util.Date

sealed trait BayesianNetworkMessage

case class ExaminationRequest (
		val patient: Patient,
		val performedOn: Date
) extends BayesianNetworkMessage

case class ExaminationResult (
		val patient: Patient,
		val examination: Examination
) extends BayesianNetworkMessage
