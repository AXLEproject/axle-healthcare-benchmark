package eu.portavita.axle.publisher

import java.io.IOException
import java.util.HashMap

import org.slf4j.LoggerFactory

import com.rabbitmq.client.Channel
import com.rabbitmq.client.ConnectionFactory
import com.rabbitmq.client.MessageProperties

import eu.portavita.axle.Generator
import eu.portavita.axle.GeneratorConfig

class RabbitMessageQueue {
	val log = LoggerFactory.getLogger(getClass())
	val config = GeneratorConfig.rabbitConfig
	val factory = new ConnectionFactory

	var channel: Channel = initChannel

	def publish(message: String, routingKey: String) {
		try {
			channel.basicPublish(config.exchangeName, routingKey, MessageProperties.TEXT_PLAIN, message.getBytes())
		} catch {
			case e: Exception =>
				log.warn("Could not publish, reconnecting.")
				channel = initChannel
				publish(message, routingKey)
		}
	}

	private def initChannel: Channel = {
		val channel = createChannel
		initExchange(channel)
	}

	private def createChannel: Channel = {
		close
		initializeFactory
		val connection = factory.newConnection()
		connection.createChannel
	}

	private def initExchange(channel: Channel): Channel = {
		try {
			channel.exchangeDeclarePassive(config.exchangeName)
			channel
		} catch {
			case e: IOException =>
				val newChannel = createChannel
				initExchangeActively(newChannel)
				newChannel
		}
	}

	private def initExchangeActively(channel: Channel) {
		val arguments = new HashMap[String, Object]()
		channel.exchangeDeclare(config.exchangeName, config.exchangeType, config.durable, config.autoDelete, false, arguments)
	}

	private def initializeFactory {
		factory.setUsername(config.username)
		factory.setPassword(config.password)
		factory.setHost(config.host)
		factory.setVirtualHost(config.virtualHost)
	}

	def close {
		try {
			if (channel != null && channel.isOpen()) channel.close()
		} catch {
			case e: IOException => log.warn("Can't close RabbitMQ channel.", e);
		}
	}

}
