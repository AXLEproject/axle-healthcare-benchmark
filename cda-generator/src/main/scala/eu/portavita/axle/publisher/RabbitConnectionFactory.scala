package eu.portavita.axle.publisher

import eu.portavita.axle.GeneratorConfig
import com.rabbitmq.client.ConnectionFactory

object RabbitConnectionFactory {

	val factory = initializeFactory

	def newConnection = factory.newConnection()

	private def initializeFactory: ConnectionFactory = {
		val factory = new ConnectionFactory
		factory.setUsername(GeneratorConfig.rabbitConfig.username)
		factory.setPassword(GeneratorConfig.rabbitConfig.password)
		factory.setHost(GeneratorConfig.rabbitConfig.host)
		factory.setVirtualHost(GeneratorConfig.rabbitConfig.virtualHost)
		factory
	}

}
