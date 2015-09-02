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
		val connection = RabbitConnectionFactory.newConnection
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

	def close {
		try {
			if (channel != null && channel.isOpen()) channel.close()
		} catch {
			case e: IOException => log.warn("Can't close RabbitMQ channel.", e);
		}
	}

}

object RabbitMessageQueue {
	val organizationRoutingKey = "generator.fhir.organization"
	val practitionerRoutingKey = "generator.fhir.practitioner"
	val patientRoutingKey = "generator.fhir.patient"
	val treatmentRoutingKey = "generator.hl7v3.treatment"
	val examinationRoutingKey = "generator.jsonb.examination"
  val consentRoutingKey = "generator.jsonb.consent"
}
