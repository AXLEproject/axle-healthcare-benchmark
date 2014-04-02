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
import net.mgrid.tranzoom.ingress.xml.XmlConverter
import javax.xml.transform.dom.DOMSource
import org.springframework.beans.factory.annotation.Required
import net.mgrid.tranzoom.error.TranzoomErrorHandler
import org.springframework.integration.annotation.ServiceActivator
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.amqp.core.MessageDeliveryMode

/**
 * Mapping class for content type routing.
 */
class InteractionMapper {

  import InteractionMapper._

  private var deliveryMode = MessageDeliveryMode.PERSISTENT

  def setDeliveryMode(mode: String): Unit = mode match {
    case "PERSISTENT" => deliveryMode = MessageDeliveryMode.PERSISTENT
    case _ => deliveryMode = MessageDeliveryMode.NON_PERSISTENT
  }

  @Autowired @Required
  var errorHandler: TranzoomErrorHandler = _

  @ServiceActivator
  def process(message: Message[DOMSource]): Message[Array[Byte]]  = {
    val result = interaction(message) map { i =>
      val payload = XmlConverter.toBytes(message.getPayload)
      MessageBuilder.withPayload(payload)
        .copyHeaders(message.getHeaders())
        .setHeader(TranzoomHeaders.CONTENT_TYPE_HEADER, i)
        .build()
    } orElse {
      logger.info(s"Determine content type failed for message $message: Unknown interaction.")
      errorHandler.error(message, ErrorUtils.ERROR_TYPE_VALIDATION, "Unsupported interaction.")
      None
    }

    if (logger.isDebugEnabled) {
      result map { m =>
        val p = new String(m.getPayload)
        logger.debug(s"Added interaction to $result")
      }
    }

    result.orNull
  }

  /**
   * Add a content type header used for downstream processing. The type is the interaction as described
   * by the message payload. If no interaction can be determined then discard message and send an error
   * to the error channel.
   *
   * @param message The message for which to add an content type header.
   * @return The message including content type header, or null if no content type could be determined.
   */
  def interaction(message: Message[DOMSource]): Option[String] = {
    val node = converter.convertToNode(message.getPayload)

    XPathEvaluationType.STRING_RESULT.evaluateXPath(messageTypeExpression, node) match {
      case "ClinicalDocument" => Some(HL7V3_CDAR2_CONTENT_TYPE)
      case "OrganizationUpdate" => Some(FHIR_ORGA_CONTENT_TYPE)
      case "PractitionerUpdate" => Some(FHIR_PRAC_CONTENT_TYPE)
      case "PatientUpdate" => Some(FHIR_PAT_CONTENT_TYPE)
      case elem @ _ => {
        logger.warn(s"Could not determine content-type for element $elem in $message")
        None
      }
    }

  }

  def deliveryModeHeader(): MessageDeliveryMode = deliveryMode

}

object InteractionMapper {
  private val logger = LoggerFactory.getLogger(InteractionMapper.getClass)

  val HL7V3_CDAR2_CONTENT_TYPE = "CDA_R2"
  val FHIR_ORGA_CONTENT_TYPE = "TZDU_IN000001UV"
  val FHIR_PRAC_CONTENT_TYPE = "TZDU_IN000002UV"
  val FHIR_PAT_CONTENT_TYPE = "TZDU_IN000003UV"

  private val converter = new DefaultXmlPayloadConverter()
  private val messageTypeExpression = XPathExpressionFactory.createXPathExpression("local-name(/*[1])")

}
