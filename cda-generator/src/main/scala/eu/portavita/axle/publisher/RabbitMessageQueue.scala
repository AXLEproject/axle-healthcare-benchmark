package eu.portavita.axle.publisher

import java.io.IOException
import java.util.HashMap

import org.slf4j.LoggerFactory

import com.rabbitmq.client.Channel
import com.rabbitmq.client.ConnectionFactory

import eu.portavita.axle.Generator
import eu.portavita.axle.GeneratorConfig


class RabbitMessageQueue {
	val log = LoggerFactory.getLogger(getClass())

    val factory = new ConnectionFactory
    factory.setHost(GeneratorConfig.rabbitConfig.host)
    var channel = initChannel

    private def initChannel: Channel = {
        val connection = factory.newConnection()
        val channel = connection.createChannel

        def declareExchange(channel: Channel) {
            val arguments = new HashMap[String, Object]()
            val config = GeneratorConfig.rabbitConfig
            channel.exchangeDeclare(config.exchangeName, config.exchangeType, config.durable, config.autoDelete, false, arguments)
        }

        def ensureExistenceOfExchange(channel: Channel) {
            try {
                declareExchange(channel)
            } catch {
                case e: IOException =>
                    log.error("Channel is closed! Shutting program down.")
                    Generator.system.shutdown()
            }
        }

        ensureExistenceOfExchange(channel)

        channel
    }

    def publish (message: String, routingKey: String) {
        try {
            channel.basicPublish(GeneratorConfig.rabbitConfig.exchangeName, routingKey, null, message.getBytes())
        } catch {
            case e: Exception =>
                log.warn("Could not publish, reconnecting.")
                channel = initChannel
                publish(message, routingKey)
        }
	}

}
