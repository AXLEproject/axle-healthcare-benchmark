package eu.portavita.axle.publisher

class RabbitMessageQueueConfig(
		val host: String,
		val exchangeName: String,
		val exchangeType: String = "topic",
		val durable: Boolean,
		val autoDelete: Boolean
		) {

}
