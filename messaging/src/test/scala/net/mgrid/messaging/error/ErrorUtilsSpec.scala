/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.messaging.error

import org.mockito.Mockito.mock
import org.mockito.Mockito.verify
import org.scalatest.FlatSpec
import org.scalatest.Matchers
import org.springframework.core.io.DefaultResourceLoader
import org.springframework.integration.MessageChannel
import org.springframework.integration.support.MessageBuilder
import org.springframework.integration.xml.selector.XmlValidatingMessageSelector
import com.rabbitmq.client.Channel
import net.mgrid.tranzoom.TranzoomHeaders
import net.mgrid.tranzoom.error.GlobalErrorHandler
import org.mockito.ArgumentCaptor
import org.springframework.integration.Message

class ErrorUtilsSpec extends FlatSpec with Matchers {
  
  import org.mockito.Mockito._
  import org.mockito.Matchers._
  
  val resourceLoader = new DefaultResourceLoader

  "Error messages" should "adhere to the xml schema" in {
    val f = fixture; import f._
    
    val validator = new XmlValidatingMessageSelector(resourceLoader.getResource("error-xsd/error.xsd"), "http://www.w3.org/2001/XMLSchema")
    validator.setThrowExceptionOnRejection(true)
    
    handler.error(msg, "type", "reason")
    
    val outArgument = ArgumentCaptor.forClass(classOf[Message[_]])
    verify(errorChannel).send(outArgument.capture())

    validator.accept(outArgument.getValue) should be (true)
  }

  def fixture = new {
    val ref = ("TEST".getBytes(), 1L, mock(classOf[Channel]))
    val msg = MessageBuilder.withPayload("message").build()
    val errorChannel = mock(classOf[MessageChannel])
    val handler = new GlobalErrorHandler()
    
    handler.setPublishErrorChannel(errorChannel)
  }
}
