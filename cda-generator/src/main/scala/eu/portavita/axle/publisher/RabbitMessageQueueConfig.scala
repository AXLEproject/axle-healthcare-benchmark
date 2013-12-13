package eu.portavita.axle.publisher

class RabbitMessageQueueConfig(
		val username: String,
		val password: String,
		val host: String,
		val virtualHost: String,
		val exchangeName: String,
		val exchangeType: String = "topic",
		val durable: Boolean,
		val autoDelete: Boolean
		) {

}
