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

class ContentTypeMapperSpec extends FlatSpec with Matchers {
  
  import org.mockito.Mockito._
  import org.mockito.Matchers._
  
  "Content type mapper" should "convert DOMSource to a string byte array" in {
    val errorChannel = mock(classOf[MessageChannel])
    val source = <ClinicalDocument xmlns="urn:hl7-org:v3"></ClinicalDocument>
    val sourceBytes = source.toString.getBytes
    val payload = XmlConverter.toDOMSource(sourceBytes)
    val sourceRef = (sourceBytes, 1L, mock(classOf[Channel]))
    val message = MessageBuilder.withPayload(payload).setHeader(TranzoomHeaders.HEADER_SOURCE_REF, sourceRef).build

    val mapper = new ContentTypeMapper
    mapper.errorChannel = errorChannel
    val result = mapper.addContentTypeHeader(message)

    verify(errorChannel, never()).send(anyObject())
    val payloadResult = new String(result.getPayload.asInstanceOf[Array[Byte]])
    XML.loadString(payloadResult) should be (source)
  }
  
  it should "add a header for CDA R2 messages" in {
    val errorChannel = mock(classOf[MessageChannel])
    val source = <ClinicalDocument xmlns="urn:hl7-org:v3"></ClinicalDocument>
    val sourceBytes = source.toString.getBytes
    val payload = XmlConverter.toDOMSource(sourceBytes)
    val sourceRef = (sourceBytes, 1L, mock(classOf[Channel]))
    val message = MessageBuilder.withPayload(payload).setHeader(TranzoomHeaders.HEADER_SOURCE_REF, sourceRef).build

    val mapper = new ContentTypeMapper
    mapper.errorChannel = errorChannel
    val result = mapper.addContentTypeHeader(message)

    verify(errorChannel, never()).send(anyObject())
    result.getHeaders.get("tz-content-type") should be ("CDA_R2")
  }

  it should "add a header for FHIR OrganizationUpdate messages" in {
    val errorChannel = mock(classOf[MessageChannel])
    val source = <OrganizationUpdate xmlns="http://hl7.org/fhir"></OrganizationUpdate>
    val sourceBytes = source.toString.getBytes
    val payload = XmlConverter.toDOMSource(sourceBytes)
    val sourceRef = (sourceBytes, 1L, mock(classOf[Channel]))
    val message = MessageBuilder.withPayload(payload).setHeader(TranzoomHeaders.HEADER_SOURCE_REF, sourceRef).build

    val mapper = new ContentTypeMapper
    mapper.errorChannel = errorChannel
    val result = mapper.addContentTypeHeader(message)

    verify(errorChannel, never()).send(anyObject())
    result.getHeaders.get("tz-content-type") should be ("TZDU_IN000001UV")
  }

  it should "add a header for FHIR PractitionerUpdate  messages" in {
    val errorChannel = mock(classOf[MessageChannel])
    val source = <PractitionerUpdate xmlns="http://hl7.org/fhir"></PractitionerUpdate>
    val sourceBytes = source.toString.getBytes
    val payload = XmlConverter.toDOMSource(sourceBytes)
    val sourceRef = (sourceBytes, 1L, mock(classOf[Channel]))
    val message = MessageBuilder.withPayload(payload).setHeader(TranzoomHeaders.HEADER_SOURCE_REF, sourceRef).build

    val mapper = new ContentTypeMapper
    mapper.errorChannel = errorChannel
    val result = mapper.addContentTypeHeader(message)

    verify(errorChannel, never()).send(anyObject())
    result.getHeaders.get("tz-content-type") should be ("TZDU_IN000002UV")
  }

  it should "add a header for FHIR PatientUpdate messages" in {
    val errorChannel = mock(classOf[MessageChannel])
    val source = <PatientUpdate xmlns="http://hl7.org/fhir"></PatientUpdate>
    val sourceBytes = source.toString.getBytes
    val payload = XmlConverter.toDOMSource(sourceBytes)
    val sourceRef = (sourceBytes, 1L, mock(classOf[Channel]))
    val message = MessageBuilder.withPayload(payload).setHeader(TranzoomHeaders.HEADER_SOURCE_REF, sourceRef).build

    val mapper = new ContentTypeMapper
    mapper.errorChannel = errorChannel
    val result = mapper.addContentTypeHeader(message)

    verify(errorChannel, never()).send(anyObject())
    result.getHeaders.get("tz-content-type") should be ("TZDU_IN000003UV")
  }

  it should "return null and send error message for unknown messages" in {
    val errorChannel = mock(classOf[MessageChannel])
    val source = <Unknown></Unknown>
    val sourceBytes = source.toString.getBytes
    val payload = XmlConverter.toDOMSource(sourceBytes)
    val sourceRef = (sourceBytes, 1L, mock(classOf[Channel]))
    val message = MessageBuilder.withPayload(payload).setHeader(TranzoomHeaders.HEADER_SOURCE_REF, sourceRef).build

    val mapper = new ContentTypeMapper
    mapper.errorChannel = errorChannel
    val result = mapper.addContentTypeHeader(message)

    verify(errorChannel).send(anyObject())
    result should be (null)
  }

  it should "support elements with a namespace prefix" in {
    val errorChannel = mock(classOf[MessageChannel])
    val source = <ns2:ClinicalDocument xmlns:ns2="urn:hl7-org:v3"></ns2:ClinicalDocument>
    val sourceBytes = source.toString.getBytes
    val payload = XmlConverter.toDOMSource(sourceBytes)
    val sourceRef = (sourceBytes, 1L, mock(classOf[Channel]))
    val message = MessageBuilder.withPayload(payload).setHeader(TranzoomHeaders.HEADER_SOURCE_REF, sourceRef).build

    val mapper = new ContentTypeMapper
    mapper.errorChannel = errorChannel
    val result = mapper.addContentTypeHeader(message)

    verify(errorChannel, never()).send(anyObject())
    result.getHeaders.get("tz-content-type") should be ("CDA_R2")
  }
}
