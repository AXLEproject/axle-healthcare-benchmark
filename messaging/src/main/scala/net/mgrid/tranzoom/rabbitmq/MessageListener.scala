/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.tranzoom.rabbitmq

import scala.beans.BeanProperty
import org.slf4j.LoggerFactory
import org.springframework.amqp.core.{ Message => AmqpMessage }
import org.springframework.amqp.rabbit.core.ChannelAwareMessageListener
import org.springframework.integration.Message
import org.springframework.integration.MessageChannel
import org.springframework.integration.amqp.AmqpHeaders
import org.springframework.integration.amqp.support.AmqpHeaderMapper
import org.springframework.integration.amqp.support.DefaultAmqpHeaderMapper
import org.springframework.integration.support.MessageBuilder
import org.xml.sax.SAXException
import com.rabbitmq.client.Channel
import net.mgrid.tranzoom.TranzoomHeaders
import net.mgrid.tranzoom.error.ErrorUtils
import net.mgrid.tranzoom.ingress.xml.XmlConverter
import javax.xml.transform.dom.DOMSource
import org.springframework.util.Assert
import net.mgrid.tranzoom.error.ErrorHandler
import javax.annotation.PostConstruct
import org.springframework.beans.factory.annotation.Required
import org.springframework.beans.factory.annotation.Autowired

/**
 * Channel-aware message listener for RabbitMQ.
 *
 * Uses manual ack mode; delegates messages ack'ing to downstream processors.
 * Stores reference to AMQP delivery tag and channel in message header.
 *
 * Main use case is to allow postponing acks until a downstream component has
 * taken full responsibility of the message (e.g., a message broker or database system).
 */
abstract class MessageListener[T] extends ChannelAwareMessageListener {
  import MessageListener._

  @BeanProperty @Required
  var outputChannel: MessageChannel = _

  @Autowired @Required
  var errorHandler: ErrorHandler = _

  private val headerMapper: AmqpHeaderMapper = new DefaultAmqpHeaderMapper

  def convert(bytes: Array[Byte]): T

  def onMessage(amqpMessage: AmqpMessage, channel: Channel): Unit =
    try {
      val tag = amqpMessage.getMessageProperties().getDeliveryTag()
      val routingKey = amqpMessage.getMessageProperties().getReceivedRoutingKey()
      val ref: SourceRef = (amqpMessage.getBody, tag, channel)
      val headers = headerMapper.toHeadersFromRequest(amqpMessage.getMessageProperties)

      try {
        val message = buildMessage(convert(amqpMessage.getBody), routingKey, ref)
        
        if (logger.isDebugEnabled) {
          logger.debug(s"Received $amqpMessage with tag $tag from RabbitMQ channel $channel, converted to $message; forward to spring message channel.")
        }

        outputChannel.send(message)

      } catch {
        case ex: SAXException => {
          // build message without conversion
          val message = buildMessage(amqpMessage.getBody(), routingKey, ref)
          logger.warn(s"Parsing of $amqpMessage failed.", ex)
          errorHandler.error(message, ErrorUtils.ERROR_TYPE_VALIDATION, s"Parse exception; ${ex.getMessage}")
        }
      }
    } catch {
      case ex: Throwable =>
        logger.error(s"Unexpected error during processing AMQP message: ${ex.getMessage}", ex)
        errorHandler.fatal(ex)
    }
    
}

object MessageListener {

  type SourceRef = (Array[Byte], Long, Channel)

  private val logger = LoggerFactory.getLogger(MessageListener.getClass)

  def buildMessage[T](payload: T, routingKey: String, ref: SourceRef) =
    MessageBuilder.withPayload(payload)
      .setHeader(TranzoomHeaders.HEADER_INGRESS_TIMESTAMP, System.currentTimeMillis.toString)
      .setHeader(TranzoomHeaders.HEADER_INGRESS_ROUTINGKEY, routingKey)
      .setHeader(TranzoomHeaders.HEADER_SOURCE_REF, ref)
      .build()

}
