/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.messaging.ingress

import org.scalatest.Matchers
import org.scalatest.FlatSpec
import org.springframework.integration.MessageChannel
import org.springframework.integration.support.MessageBuilder
import net.mgrid.tranzoom.ingress.ContentTypeMapper
import com.rabbitmq.client.Channel
import net.mgrid.tranzoom.TranzoomHeaders
import net.mgrid.tranzoom.ingress.xml.XmlConverter
import scala.xml.XML
import net.mgrid.tranzoom.error.GlobalErrorHandler
import org.springframework.integration.Message
import scala.xml.Elem
import javax.xml.transform.dom.DOMSource

class ContentTypeMapperSpec extends FlatSpec with Matchers {
  
  import org.mockito.Mockito._
  import org.mockito.Matchers._
  
  "Content type mapper" should "convert DOMSource to a string byte array" in {
    val f = fixture; import f._
    
    val source = <ClinicalDocument xmlns="urn:hl7-org:v3"></ClinicalDocument>
    val message = msg(source)
    val result = mapper.addContentTypeHeader(message)

    verify(errorHandler, never()).error(anyObject(), anyString(), anyString())
    verify(errorHandler, never()).fatal(anyObject())
    val payloadResult = new String(result.getPayload.asInstanceOf[Array[Byte]])
    XML.loadString(payloadResult) should be (source)
  }
  
  it should "add a header for CDA R2 messages" in {
    contentTypeCheck(<ClinicalDocument xmlns="urn:hl7-org:v3"></ClinicalDocument>, "CDA_R2")
  }

  it should "add a header for FHIR OrganizationUpdate messages" in {
    contentTypeCheck(<OrganizationUpdate xmlns="http://hl7.org/fhir"></OrganizationUpdate>, "TZDU_IN000001UV")
  }

  it should "add a header for FHIR PractitionerUpdate  messages" in {
    contentTypeCheck(<PractitionerUpdate xmlns="http://hl7.org/fhir"></PractitionerUpdate>, "TZDU_IN000002UV")
  }

  it should "add a header for FHIR PatientUpdate messages" in {
    contentTypeCheck(<PatientUpdate xmlns="http://hl7.org/fhir"></PatientUpdate>, "TZDU_IN000003UV")
  }

  it should "return null and send error message for unknown messages" in {
    val f = fixture; import f._
    val source = <Unknown></Unknown>
    val message = msg(source)
    val result = mapper.addContentTypeHeader(message)

    verify(errorHandler).error(anyObject(), anyString(), anyString())
    verify(errorHandler, never()).fatal(anyObject())
    result should be (null)
  }

  it should "support elements with a namespace prefix" in {
    val f = fixture; import f._
    val source = <ns2:ClinicalDocument xmlns:ns2="urn:hl7-org:v3"></ns2:ClinicalDocument>
    val message = msg(source)
    val result = mapper.addContentTypeHeader(message)

    verify(errorHandler, never()).error(anyObject(), anyString(), anyString())
    verify(errorHandler, never()).fatal(anyObject())
    result.getHeaders.get("tz-content-type") should be ("CDA_R2")
  }
  
  def contentTypeCheck(source: Elem, expectedContentType: String): Unit = {
    val f = fixture; import f._
    val message = msg(source)
    val result = mapper.addContentTypeHeader(message)

    verify(errorHandler, never()).error(anyObject(), anyString(), anyString())
    verify(errorHandler, never()).fatal(anyObject())
    result.getHeaders.get("tz-content-type") should be (expectedContentType)
  }
  
  def fixture = new {
    val errorHandler = mock(classOf[GlobalErrorHandler])
    
    def msg(source: Elem): Message[DOMSource] = {
    val sourceBytes = source.toString.getBytes
    val payload = XmlConverter.toDOMSource(sourceBytes)
    val sourceRef = (sourceBytes, 1L, mock(classOf[Channel]))
    MessageBuilder.withPayload(payload).build
    }

    val mapper = new ContentTypeMapper
    mapper.errorHandler = errorHandler
  }
}
