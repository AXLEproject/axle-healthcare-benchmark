/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.tranzoom.error

import org.springframework.integration.MessageChannel
import org.springframework.integration.Message
import org.slf4j.LoggerFactory
import scala.beans.BeanProperty
import org.springframework.integration.MessagingException
import net.mgrid.tranzoom.TranzoomHeaders
import net.mgrid.tranzoom.rabbitmq.MessageListener
import org.springframework.integration.annotation.ServiceActivator
import org.springframework.beans.factory.annotation.Required

trait ErrorHandler {
  def error(source: Message[_], errorType: String, reason: String): Unit
  def fatal(ex: Throwable): Unit
}

/**
 * Exception handling code.
 *
 * Tries to publish an error message to the broker
 */
class GlobalErrorHandler extends ErrorHandler with XmlErrorFormat with ForceExitOnFail {
  import GlobalErrorHandler._

  @BeanProperty @Required
  var publishErrorChannel: MessageChannel = _

  override def error(source: Message[_], errorType: String, reason: String): Unit =
    handle(sendError(source, errorType, Option(reason)))

  override def fatal(ex: Throwable): Unit = {
    logger.error(s"Unrecoverable error occurred: ${ex.getMessage}", ex)
    fail
  }

  @ServiceActivator
  def globalError(ex: MessagingException): Unit =
    handle(sendError(ex.getFailedMessage(), ErrorUtils.ERROR_TYPE_INTERNAL, Option(ex.getCause().getMessage())))

  private def handle(f: => Unit): Unit =
    try {
      f
    } catch {
      case ex: Throwable =>
        logger.error(s"Unexpected error during error handling. ${ex.getMessage} $ex")
        fail
    }

  private def sendError(failedMessage: Message[_], errorType: String, reason: Option[String]) = {
    import MessageListener.SourceRef
    logger.info(s"Message handling failed for $failedMessage: $reason")
    val ref = failedMessage.getHeaders.get(TranzoomHeaders.HEADER_SOURCE_REF).asInstanceOf[SourceRef]
    val error = errorMessage(ErrorUtils.ERROR_TYPE_VALIDATION, reason.getOrElse("Unknown"), ref)
    publishErrorChannel.send(error)
  }

}

private object GlobalErrorHandler {
  private val logger = LoggerFactory.getLogger(GlobalErrorHandler.getClass)
}

/**
 * Mixin which exits JVM on fail.
 *
 * Useful when connected to RabbitMQ and forcing unacked messages to be returned to the queue.
 */
trait ForceExitOnFail {
  def fail = System.exit(1)
}

trait XmlErrorFormat {
  import scala.xml.PCData
  import org.springframework.integration.support.MessageBuilder
  import scala.xml.XML
  import java.io.StringWriter
  import MessageListener.SourceRef

  def errorMessage(errorType: String, reason: String, ref: SourceRef): Message[_] = {
    val (payload, _, _) = ref
    val sourcePayload = new String(payload)

    val xmlPayload =
      <error xmlns="urn:mgrid-net:tranzoom">
        <type>{ errorType }</type>
        <reason>{ PCData(reason) }</reason>
        <source>{ PCData(sourcePayload) }</source>
      </error>

    // we need this to include the xml declaration
    val payloadWriter = new StringWriter
    XML.write(payloadWriter, xmlPayload, "UTF-8", true, null)

    MessageBuilder.withPayload(payloadWriter.toString)
      .setHeader(TranzoomHeaders.HEADER_SOURCE_REF, ref)
      .build()
  }
}
