/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.messaging.xml

import org.springframework.integration.xml.selector.XmlValidatingMessageSelector
import org.springframework.integration.MessageChannel
import org.scalatest.FlatSpec
import net.mgrid.tranzoom.ingress.xml.XmlValidator
import org.springframework.integration.Message
import org.springframework.integration.support.MessageBuilder
import org.springframework.integration.MessageRejectedException
import org.scalatest.Matchers
import net.mgrid.tranzoom.TranzoomHeaders
import com.rabbitmq.client.Channel

class XmlValidatorSpec extends FlatSpec with Matchers {
  
  import org.mockito.Mockito._
  import org.mockito.Matchers._
  
  val source = ("TEST".getBytes(), 1L, mock(classOf[Channel]))

  "XML Validator" should "return validated messages" in {
    val errorChannel = mock(classOf[MessageChannel])
    val selector = mock(classOf[XmlValidatingMessageSelector])
    val message = MessageBuilder
      .withPayload("TEST")
      .setHeader(TranzoomHeaders.HEADER_SOURCE_REF, source)
      .build

    when(selector.accept(message)).thenReturn(true)

    val validator = new XmlValidator
    validator.errorChannel = errorChannel
    validator.selector= selector
    val result = validator.validate(message)

    verify(errorChannel, never()).send(anyObject())
    result.getPayload should be (message.getPayload)
  }

  it should "return null and send an error message on the error channel for invalid messages" in {
    val errorChannel = mock(classOf[MessageChannel])
    val selector = mock(classOf[XmlValidatingMessageSelector])
    val message = MessageBuilder
      .withPayload("TEST")
      .setHeader(TranzoomHeaders.HEADER_SOURCE_REF, source)
      .build

    when(selector.accept(message)).thenThrow(new MessageRejectedException(message))

    val validator = new XmlValidator
    validator.errorChannel = errorChannel
    validator.selector= selector
    val result = validator.validate(message)

    verify(errorChannel).send(anyObject())
    result should be (null)
  }

  it should "return null and send an error message on the error channel for message exceptions" in {
    val errorChannel = mock(classOf[MessageChannel])
    val selector = mock(classOf[XmlValidatingMessageSelector])
    val message = MessageBuilder
      .withPayload("TEST")
      .setHeader(TranzoomHeaders.HEADER_SOURCE_REF, source)
      .build

    when(selector.accept(message)).thenThrow(new RuntimeException("Random exception during validating"))

    val validator = new XmlValidator
    validator.errorChannel = errorChannel
    validator.selector= selector
    val result = validator.validate(message)

    verify(errorChannel).send(anyObject())
    result should be (null)
  }
}
