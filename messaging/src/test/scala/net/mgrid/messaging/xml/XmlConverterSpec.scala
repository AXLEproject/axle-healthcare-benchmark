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
import net.mgrid.tranzoom.ingress.xml.XmlConverter
import scala.xml.XML

class XmlConverterSpec extends FlatSpec with Matchers {
  
  import org.mockito.Mockito._
  import org.mockito.Matchers._
  
  val source = ("TEST".getBytes(), 1L, mock(classOf[Channel]))

  "XML Converter" should "convert between bytes and DOMSource" in {
    val input = <test></test>.toString
    val inputBytes = input.getBytes()
    val domsrc = XmlConverter.toDOMSource(inputBytes)
    val outputBytes = XmlConverter.toBytes(domsrc)
    val output = new String(outputBytes)
    
    // we convert to Elem for comparison to ignore formatting differences
    XML.loadString(input) should be (XML.loadString(output))
  }
}
