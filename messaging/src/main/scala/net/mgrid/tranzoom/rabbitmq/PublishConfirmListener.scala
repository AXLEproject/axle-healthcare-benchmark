/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.tranzoom.rabbitmq

import org.springframework.integration.MessageChannel
import net.mgrid.tranzoom.error.ErrorUtils
import org.springframework.integration.Message
import scala.beans.BeanProperty
import org.springframework.integration.amqp.AmqpHeaders
import net.mgrid.tranzoom.TranzoomHeaders
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Required
import net.mgrid.tranzoom.error.ErrorHandler
import org.springframework.integration.support.MessageBuilder
import org.springframework.integration.annotation.ServiceActivator
import org.springframework.beans.factory.annotation.Autowired

/**
 * Listener for downstream confirms, sends ack upstream.
 */
class PublishConfirmListener {
  import PublishConfirmListener._
  import MessageListener.SourceRef

  @Autowired @Required
  var errorHandler: ErrorHandler = _

  @ServiceActivator
  def publishResult(message: Message[SourceRef]): Unit =
    message.getHeaders.get(AmqpHeaders.PUBLISH_CONFIRM) match {
      case isConfirm: java.lang.Boolean if isConfirm => confirmMessage(message.getPayload)
      case _ => {
        val ref @ (payload, _, _) = message.getPayload()
        val source = MessageBuilder.withPayload(payload).setHeader(TranzoomHeaders.HEADER_SOURCE_REF, ref).build
        errorHandler.error(source, ErrorUtils.ERROR_TYPE_INTERNAL, "Message rejected by message broker.")
      }
    }

  def deliverConfirm(message: Message[_]): Unit =
    message.getHeaders.get(TranzoomHeaders.HEADER_SOURCE_REF) match {
      case ref: SourceRef => confirmMessage(ref)
    }

  def errorReject(message: Message[SourceRef]): Unit = {
    logger.warn(s"Error message rejected by message broker, we give up and send a nack for the source message.")
    rejectMessage(message.getPayload)
  }

  private def confirmMessage(ref: SourceRef): Unit = ref match {
    case (_, tag, channel) => {
      if (logger.isDebugEnabled()) {
        logger.debug(s"Received publish confirm for tag $tag")
      }
      channel.basicAck(tag, false)
    }
    case _ => logger.warn(s"Invalid source reference found for ack: $ref")
  }

  private def rejectMessage(ref: SourceRef): Unit = ref match {
    case (_, tag, channel) => channel.basicNack(tag, false, true)
    case _ => logger.warn(s"Invalid source reference found for nack: $ref")
  }
}

object PublishConfirmListener {
  private val logger = LoggerFactory.getLogger(PublishConfirmListener.getClass)
}