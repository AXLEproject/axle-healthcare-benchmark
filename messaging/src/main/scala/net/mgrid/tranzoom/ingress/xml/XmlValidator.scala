/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.tranzoom.ingress.xml

import org.springframework.integration.xml.selector.XmlValidatingMessageSelector
import org.springframework.integration.Message
import org.springframework.integration.MessageRejectedException
import org.springframework.integration.xml.AggregatedXmlMessageValidationException
import org.springframework.integration.support.MessageBuilder
import org.springframework.beans.factory.annotation.Qualifier
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.integration.MessageChannel
import net.mgrid.tranzoom.error.ErrorUtils
import scala.util.Try
import scala.util.Failure
import scala.util.Success
import org.slf4j.LoggerFactory
import scala.beans.BeanProperty
import net.mgrid.tranzoom.TranzoomHeaders
import net.mgrid.tranzoom.rabbitmq.MessageListener

/**
 * Validate XML messages.
 */
class XmlValidator {

  import XmlValidator._
  import MessageListener.SourceRef

  @BeanProperty
  var errorChannel: MessageChannel = _

  @BeanProperty
  var selector: XmlValidatingMessageSelector = _

  def validate(message: Message[_]): Message[_] = {

    val result = Try(selector.accept(message)) match {
      case Success(_) => message
      case Failure(ex) => error(message, ex)
    }

    if (logger.isDebugEnabled) {
      logger.debug(s"Validate $message; resulting message to output channel (null for no forwarding): $result")
    }

    result
  }

  private def error(message: Message[_], cause: Throwable): Message[_] = {
    import scala.collection.JavaConverters.asScalaIteratorConverter
    import net.mgrid.tranzoom.error.ErrorUtils
    
    val ref = message.getHeaders.get(TranzoomHeaders.HEADER_SOURCE_REF) match {
      case ref: SourceRef => ref
    }

    cause match {
      case ex: MessageRejectedException => ex.getCause match {
        case xmlException: AggregatedXmlMessageValidationException => {
          val reason = xmlException.exceptionIterator.asScala.map(_.getMessage).mkString("\n")
          val errorMessage = ErrorUtils.errorMessage(ErrorUtils.ERROR_TYPE_VALIDATION, reason, ref)
          logger.info(s"Schema validation failed for message $message: $reason. Sending error message: $errorMessage")
          errorChannel.send(errorMessage)
        }
        case ex @ _ => {
          logger.warn(s"Unknown message rejection cause $ex for message $message")
          val errorMessage = ErrorUtils.errorMessage(ErrorUtils.ERROR_TYPE_INTERNAL, "Internal server error", ref)
          errorChannel.send(errorMessage)
        }
      }
      case ex: Throwable => {
        logger.warn(s"Unknown exception thrown during validation of $message", ex)
        val errorMessage = ErrorUtils.errorMessage(ErrorUtils.ERROR_TYPE_INTERNAL, "Internal server error", ref)
        errorChannel.send(errorMessage)
      }
    }

    // always return null so no message is routed to output channel
    null
  }

}

object XmlValidator {
  private val logger = LoggerFactory.getLogger(XmlValidator.getClass)
}
