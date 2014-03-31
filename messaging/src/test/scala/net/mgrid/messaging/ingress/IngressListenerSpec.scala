/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.messaging.ingress

import org.mockito.ArgumentCaptor
import org.mockito.Matchers.anyBoolean
import org.mockito.Matchers.anyLong
import org.mockito.Matchers.anyObject
import org.mockito.Mockito.mock
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.mockito.Mockito.when
import org.scalatest.FlatSpec
import org.scalatest.Matchers
import org.springframework.amqp.core.{Message => AmqpMessage}
import org.springframework.amqp.core.MessageProperties
import org.springframework.integration.MessageChannel
import org.springframework.integration.Message
import com.rabbitmq.client.Channel
import net.mgrid.tranzoom.ingress.IngressListener
import net.mgrid.tranzoom.TranzoomHeaders
import java.nio.charset.Charset
import net.mgrid.tranzoom.ingress.xml.XmlConverter
import javax.xml.transform.dom.DOMSource
import scala.xml.XML
import net.mgrid.tranzoom.error.GlobalErrorHandler

class IngressListenerSpec extends FlatSpec with Matchers {

  import org.mockito.Mockito._
  import org.mockito.Matchers._

  "The ingress listener" should "forward messages to the output channel as DOMSource" in {
    val f = fixture; import f._
    listener.onMessage(msg, channel)

    // ack's should not be sent synchronously
    verify(channel, never()).basicAck(anyLong(), anyBoolean())
    verify(errorHandler, never()).error(anyObject(), anyString(), anyString())
    verify(errorHandler, never()).fatal(anyObject())
    
    val outArgument = ArgumentCaptor.forClass(classOf[Message[_]])
    verify(outputChannel).send(outArgument.capture())
    val result = outArgument.getValue.getPayload.asInstanceOf[DOMSource]
    val stringResult = new String(XmlConverter.toBytes(result))
    
    XML.loadString(stringResult) should be (XML.loadString(payload))
  }
  
  it should "send errors to the error channel" in {
    val f = fixture; import f._
    when(outputChannel.send(anyObject())).thenThrow(new RuntimeException("Message forwarding failed"))
    
    listener.onMessage(msg, channel)

    // ack's should not be sent synchronously
    verify(channel, never()).basicAck(anyLong(), anyBoolean())
    verify(errorHandler, never()).error(anyObject(), anyString(), anyString())
    verify(errorHandler).fatal(anyObject())
  }

  it should "add timestamp header" in {
    val f = fixture; import f._
    listener.onMessage(msg, channel)

    // ack's should not be sent synchronously
    verify(channel, never()).basicAck(anyLong(), anyBoolean())
    val outArgument = ArgumentCaptor.forClass(classOf[Message[_]])
    verify(outputChannel).send(outArgument.capture())
    val header = outArgument.getValue.getHeaders.get(TranzoomHeaders.HEADER_INGRESS_TIMESTAMP).toString
    header should fullyMatch regex """\d+"""
  }
  
  def fixture = new {
    val outputChannel = mock(classOf[MessageChannel])
    val errorHandler = mock(classOf[GlobalErrorHandler])
    val channel = mock(classOf[Channel])
    val msg = mock(classOf[AmqpMessage])
    val payload = "<test></test>"
    val props = new MessageProperties

    props.setDeliveryTag(1L)
    props.setContentType("text/plain")
    props.setContentEncoding("UTF-8")
    when(msg.getMessageProperties).thenReturn(props)
    when(msg.getBody).thenReturn(payload.getBytes())

    val listener = new IngressListener
    listener.outputChannel = outputChannel
    listener.errorHandler = errorHandler
  }
}
