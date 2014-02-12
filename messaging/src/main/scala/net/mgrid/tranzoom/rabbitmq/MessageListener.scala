/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.tranzoom.rabbitmq

import scala.beans.BeanProperty
import org.slf4j.LoggerFactory
import org.springframework.amqp.core.{Message => AmqpMessage}
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

  @BeanProperty
  var outputChannel: MessageChannel = _

  @BeanProperty
  var errorChannel: MessageChannel = _

  private val headerMapper: AmqpHeaderMapper = new DefaultAmqpHeaderMapper

  def convert(bytes: Array[Byte]): T

  def onMessage(message: AmqpMessage, channel: Channel): Unit = {
    Assert.notNull(message.getMessageProperties())
    Assert.notNull(message.getMessageProperties().getDeliveryTag())

    val tag = message.getMessageProperties().getDeliveryTag()
    val ref = (message.getBody, tag, channel)

    try {
      val payload = convert(message.getBody)
      val headers = headerMapper.toHeadersFromRequest(message.getMessageProperties)
      val m = MessageBuilder
        .withPayload(payload)
        .copyHeaders(headers)
        .setHeader(TranzoomHeaders.HEADER_INGRESS_TIMESTAMP, System.currentTimeMillis.toString)
        .setHeader(TranzoomHeaders.HEADER_SOURCE_REF, ref)
        .build()

      if (logger.isDebugEnabled) {
        logger.debug(s"Received $message with tag $tag from RabbitMQ channel $channel, converted to $m; forward to spring message channel.")
      }

      outputChannel.send(m)

    } catch {
      case ex: SAXException => {
        logger.warn(s"Parsing of $message failed.", ex)
        val errorMessage = ErrorUtils.errorMessage(ErrorUtils.ERROR_TYPE_VALIDATION, s"Parse exception; ${ex.getMessage}", ref)
        errorChannel.send(errorMessage)
      }
      case ex: Throwable => {
        logger.warn(s"Processing of $message failed.", ex)
        val errorMessage = ErrorUtils.errorMessage(ErrorUtils.ERROR_TYPE_INTERNAL, s"Exception during message processing: ${ex.getMessage}", ref)
        errorChannel.send(errorMessage)
      }
    }
  }
}

object MessageListener {

  type SourceRef = (Array[Byte], Long, Channel)

  private val logger = LoggerFactory.getLogger(MessageListener.getClass)

}
