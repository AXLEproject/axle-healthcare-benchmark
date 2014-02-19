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

class XmlConverterSpec extends FlatSpec with Matchers {
  
  import org.mockito.Mockito._
  import org.mockito.Matchers._
  
  val source = ("TEST".getBytes(), 1L, mock(classOf[Channel]))

  ignore should "convert bytes to DOMSource" in {
    throw new Exception("Not implemented yet")
  }
}
