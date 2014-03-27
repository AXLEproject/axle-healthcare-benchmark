package eu.portavita.axle.publisher

import akka.actor.Actor
import akka.actor.ActorLogging
import eu.portavita.axle.generators.InPipeline

sealed abstract trait PublishMessage
case class PublishMessageRequest(content: String, routingKey: String) extends PublishMessage

class RabbitMessageQueueActor extends Actor with ActorLogging {

	private val publisher = new RabbitMessageQueue

	def receive = {
		case PublishMessageRequest(content, routingKey) =>
			publisher.publish(content, routingKey)
			val inPipeline = InPipeline.publishRequests.finishRequest
			if (inPipeline > 0 && inPipeline % 500 == 0) log.info("%d publish requests in pipeline".format(inPipeline))

		case x => log.warning("Received message that I cannot handle: " + x.toString)
	}
}
