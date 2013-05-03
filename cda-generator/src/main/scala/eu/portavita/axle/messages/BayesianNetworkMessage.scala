/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.messages

import eu.portavita.axle.generatable.Examination
import eu.portavita.axle.generatable.Patient
import akka.actor.ActorRef

sealed trait BayesianNetworkMessage

case class ExaminationRequest (
		val patient: Patient
) extends BayesianNetworkMessage

case class ExaminationResult (
		val patient: Patient,
		val examination: Examination
) extends BayesianNetworkMessage
