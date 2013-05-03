/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.actors

import akka.actor.ActorLogging
import akka.actor.Actor
import eu.portavita.axle.messages.IdResult
import eu.portavita.axle.messages.IdRequest

/**
 * This actor receives request for global unique ids.
 */
class IdActor extends Actor with ActorLogging {

	// Start ids at 1.
	private var id = 1

	/**
	 * Receives messages.
	 */
	def receive = {

		/**
		 * Returns the next unique id.
		 *
		 * @return
		 */
		case IdRequest(n) =>
			sender ! IdResult(id)
			id += n

		case x =>
			log.warning("Received message that I cannot handle: " + x.toString)
	}

}