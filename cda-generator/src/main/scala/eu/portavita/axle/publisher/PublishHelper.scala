package eu.portavita.axle.publisher

import akka.actor.ActorSelection
import eu.portavita.axle.generators.InPipeline

class PublishHelper(publisher: ActorSelection) {

	def publish(content: String, routingKey: String) {
		publisher ! PublishMessageRequest(content, routingKey)
		InPipeline.publishRequests.newRequest
	}
}
