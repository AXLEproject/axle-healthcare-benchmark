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
import net.mgrid.tranzoom.error.GlobalErrorHandler
import org.springframework.xml.validation.XmlValidatorFactory
import org.springframework.core.io.DefaultResourceLoader
import scala.io.Source

class XmlValidatorSpec extends FlatSpec with Matchers {
  
  import org.mockito.Mockito._
  import org.mockito.Matchers._
  
  "XML Validator" should "return validated messages" in {
    val f = fixture; import f._

    when(selector.accept(msg)).thenReturn(true)

    val result = validator.validate(msg)

    verify(errorHandler, never()).error(anyObject(), anyString(), anyString())
    verify(errorHandler, never()).fatal(anyObject())
    result.getPayload should be (msg.getPayload)
  }

  it should "return null and send an error message on the error channel for invalid messages" in {
    val f = fixture; import f._

    when(selector.accept(msg)).thenThrow(new MessageRejectedException(msg))

    val result = validator.validate(msg)

    verify(errorHandler).error(anyObject(), anyString(), anyString())
    verify(errorHandler, never()).fatal(anyObject())
    result should be (null)
  }

  it should "return null and send an error message on the error channel for message exceptions" in {
    val f = fixture; import f._
    
    when(selector.accept(msg)).thenThrow(new RuntimeException("Random exception during validating"))

    val result = validator.validate(msg)

    verify(errorHandler).error(anyObject(), anyString(), anyString())
    verify(errorHandler, never()).fatal(anyObject())
    result should be (null)
  }
  
  def fixture = new {
    val resourceLoader = new DefaultResourceLoader()
    val errorHandler = mock(classOf[GlobalErrorHandler])
    val source = ("TEST".getBytes(), 1L, mock(classOf[Channel]))
    val selector = mock(classOf[XmlValidatingMessageSelector])
    val msg = MessageBuilder
      .withPayload("TEST")
      .setHeader(TranzoomHeaders.HEADER_SOURCE_REF, source)
      .build

    val validator = new XmlValidator
    validator.errorHandler = errorHandler
    validator.selector= selector
  }
}
