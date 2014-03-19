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
import org.springframework.integration.annotation.ServiceActivator
import org.springframework.beans.factory.annotation.Required
import org.springframework.util.ErrorHandler
import net.mgrid.tranzoom.ingress.xml.XmlConverter
import javax.xml.transform.dom.DOMSource

trait TranzoomErrorHandler extends ErrorHandler {
  def error(source: Message[_], errorType: String, reason: String): Unit
  def fatal(ex: Throwable): Unit
}

/**
 * Exception handling code.
 *
 * Tries to publish an error message to the broker
 */
class GlobalErrorHandler extends TranzoomErrorHandler with XmlErrorFormat {
  import GlobalErrorHandler._

  @BeanProperty @Required
  var publishErrorChannel: MessageChannel = _
  
  override def handleError(ex: Throwable): Unit = fatal(ex)

  override def error(source: Message[_], errorType: String, reason: String): Unit =
    handle(sendError(source, errorType, Option(reason)))

  override def fatal(ex: Throwable): Unit = {
    logger.error(s"Unrecoverable error occurred: ${ex.getMessage}", ex)
    throw ex
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
        fatal(ex)
    }

  private def sendError(failedMessage: Message[_], errorType: String, reason: Option[String]) = {
    logger.info(s"Message handling failed for $failedMessage: $reason")
    val error = errorMessage(failedMessage, ErrorUtils.ERROR_TYPE_VALIDATION, reason.getOrElse("Unknown"))
    publishErrorChannel.send(error)
  }

}

private object GlobalErrorHandler {
  private val logger = LoggerFactory.getLogger(GlobalErrorHandler.getClass)
}

trait XmlErrorFormat {
  import scala.xml.PCData
  import org.springframework.integration.support.MessageBuilder
  import scala.xml.XML
  import java.io.StringWriter

  def errorMessage[T](message: Message[T], errorType: String, reason: String): Message[String] = {
    val sourcePayload = message.getPayload() match {
      case ds: DOMSource => new String(XmlConverter.toBytes(ds))
      case s: String => s
      case payload @ _ => payload.toString
    }

    val xmlPayload =
      <error xmlns="urn:mgrid-net:tranzoom">
        <type>{ errorType }</type>
        <reason>{ PCData(reason) }</reason>
        <source>{ PCData(sourcePayload) }</source>
      </error>

    // we need this to include the xml declaration
    val payloadWriter = new StringWriter
    XML.write(payloadWriter, xmlPayload, "UTF-8", true, null)

    MessageBuilder.withPayload(payloadWriter.toString).build()
  }
}
