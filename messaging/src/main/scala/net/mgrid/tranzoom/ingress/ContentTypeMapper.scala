/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.tranzoom.ingress

import org.springframework.integration.Message
import org.slf4j.LoggerFactory
import org.springframework.integration.xml.xpath.XPathEvaluationType
import org.springframework.integration.xml.DefaultXmlPayloadConverter
import org.springframework.xml.xpath.XPathExpressionFactory
import org.springframework.integration.support.MessageBuilder
import org.springframework.integration.amqp.AmqpHeaders
import org.springframework.integration.MessageChannel
import scala.beans.BeanProperty
import net.mgrid.tranzoom.error.ErrorUtils
import net.mgrid.tranzoom.TranzoomHeaders
import net.mgrid.tranzoom.rabbitmq.MessageListener
import net.mgrid.tranzoom.ingress.xml.XmlConverter
import javax.xml.transform.dom.DOMSource

/**
 * Mapping class for content type routing.
 */
class ContentTypeMapper {

  import ContentTypeMapper._
  import MessageListener.SourceRef

  @BeanProperty
  var errorChannel: MessageChannel = _

  /**
   * Add a content type header used for downstream processing. The type is the interaction as described
   * by the message payload. If no interaction can be determined then discard message and send an error
   * to the error channel.
   *
   * @param message The message for which to add an content type header.
   * @return The message including content type header, or null if no content type could be determined.
   */
  def addContentTypeHeader(message: Message[DOMSource]): Message[Array[Byte]] = {
    val node = converter.convertToNode(message.getPayload)
    val contentType: Option[String] = XPathEvaluationType.STRING_RESULT.evaluateXPath(messageTypeExpression, node) match {
      case "ClinicalDocument" => Some(HL7V3_CDAR2_CONTENT_TYPE)
      case "OrganizationUpdate" => Some(FHIR_ORGA_CONTENT_TYPE)
      case "PractitionerUpdate" => Some(FHIR_PRAC_CONTENT_TYPE)
      case "PatientUpdate" => Some(FHIR_PAT_CONTENT_TYPE)
      case elem @ _ => {
        logger.warn(s"Could not determine content-type for element $elem in $message")
        None
      }
    }

    val result = contentType map { ct =>
      val payload = XmlConverter.toBytes(message.getPayload)
      MessageBuilder.withPayload(payload).copyHeaders(message.getHeaders()).setHeader(CONTENT_TYPE_HEADER, ct).build()
    } getOrElse {
      message.getHeaders.get(TranzoomHeaders.HEADER_SOURCE_REF) match {
        case ref: SourceRef => {
          val reason = s"Unsupported interaction."
          val errorMessage = ErrorUtils.errorMessage(ErrorUtils.ERROR_TYPE_VALIDATION, reason, ref)
          logger.info(s"Determine content type failed for message $message: $reason. Sending error message: $errorMessage")
          errorChannel.send(errorMessage)
          null
        }
      }
    }
    
    if (logger.isDebugEnabled) {
      val p = new String(result.getPayload())
      logger.debug(s"Added content type header $contentType to result message $result with payload $p")
    }
    
    result
  }

}

private object ContentTypeMapper {
  private val logger = LoggerFactory.getLogger(ContentTypeMapper.getClass)

  private val CONTENT_TYPE_HEADER = "tz-content-type"

  private val HL7V3_CDAR2_CONTENT_TYPE = "CDA_R2"
  private val FHIR_ORGA_CONTENT_TYPE = "TZDU_IN000001UV"
  private val FHIR_PRAC_CONTENT_TYPE = "TZDU_IN000002UV"
  private val FHIR_PAT_CONTENT_TYPE = "TZDU_IN000003UV"

  private val converter = new DefaultXmlPayloadConverter()
  private val messageTypeExpression = XPathExpressionFactory.createXPathExpression("local-name(/*[1])")

}
