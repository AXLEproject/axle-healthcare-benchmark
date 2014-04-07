/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.messaging.ingress

import org.scalatest.Matchers
import org.scalatest.FlatSpec
import org.springframework.integration.MessageChannel
import org.springframework.integration.support.MessageBuilder
import net.mgrid.tranzoom.ingress.InteractionMapper
import com.rabbitmq.client.Channel
import net.mgrid.tranzoom.TranzoomHeaders
import net.mgrid.tranzoom.ingress.xml.XmlConverter
import scala.xml.XML
import net.mgrid.tranzoom.error.GlobalErrorHandler
import org.springframework.integration.Message
import scala.xml.Elem
import javax.xml.transform.dom.DOMSource

class InteractionMapperSpec extends FlatSpec with Matchers {

  import org.mockito.Mockito._
  import org.mockito.Matchers._

  "Interaction mapper" should "convert DOMSource to a string byte array" in {
    val f = fixture; import f._

    val source = <ClinicalDocument xmlns="urn:hl7-org:v3"></ClinicalDocument>
    val message = msg(source)
    val result = mapper.process(message)

    verify(errorHandler, never()).error(anyObject(), anyString(), anyString())
    verify(errorHandler, never()).fatal(anyObject())
    val payloadResult = new String(result.getPayload.asInstanceOf[Array[Byte]])
    XML.loadString(payloadResult) should be (source)
  }

  it should "add a header for CDA R2 messages" in {
    interactionCheck(<ClinicalDocument xmlns="urn:hl7-org:v3"></ClinicalDocument>, "CDA_R2")
  }

  it should "add a header for FHIR OrganizationUpdate messages" in {
    interactionCheck(<OrganizationUpdate xmlns="http://hl7.org/fhir"></OrganizationUpdate>, "TZDU_IN000001UV")
  }

  it should "add a header for FHIR PractitionerUpdate  messages" in {
    interactionCheck(<PractitionerUpdate xmlns="http://hl7.org/fhir"></PractitionerUpdate>, "TZDU_IN000002UV")
  }

  it should "add a header for FHIR PatientUpdate messages" in {
    interactionCheck(<PatientUpdate xmlns="http://hl7.org/fhir"></PatientUpdate>, "TZDU_IN000003UV")
  }

  it should "return null and send error message for unknown messages" in {
    val f = fixture; import f._
    val source = <Unknown></Unknown>
    val message = msg(source)
    val result = mapper.process(message)

    verify(errorHandler).error(anyObject(), anyString(), anyString())
    verify(errorHandler, never()).fatal(anyObject())
    result should be (null)
  }

  it should "support elements with a namespace prefix" in {
    interactionCheck(<ns2:ClinicalDocument xmlns:ns2="urn:hl7-org:v3"></ns2:ClinicalDocument>, "CDA_R2")
  }

  def interactionCheck(source: Elem, expectedInteraction: String): Unit = {
    val f = fixture; import f._
    val message = msg(source)
    val result = mapper.process(message)

    verify(errorHandler, never()).error(anyObject(), anyString(), anyString())
    verify(errorHandler, never()).fatal(anyObject())
    result.getHeaders.get("tz-content-type") should be (expectedInteraction)
  }

  def fixture = new {
    val errorHandler = mock(classOf[GlobalErrorHandler])

    def msg(source: Elem): Message[DOMSource] = {
    val sourceBytes = source.toString.getBytes
    val payload = XmlConverter.toDOMSource(sourceBytes)
    val sourceRef = (sourceBytes, 1L, mock(classOf[Channel]))
    MessageBuilder.withPayload(payload).build
    }

    val mapper = new InteractionMapper
    mapper.errorHandler = errorHandler
  }
}
