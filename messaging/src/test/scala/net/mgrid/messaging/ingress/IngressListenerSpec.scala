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

class IngressListenerSpec extends FlatSpec with Matchers {

  import org.mockito.Mockito._
  import org.mockito.Matchers._

  "The ingress listener" should "forward messages to the output channel as DOMSource" in {
    val outputChannel = mock(classOf[MessageChannel])
    val errorChannel = mock(classOf[MessageChannel])
    val channel = mock(classOf[Channel])
    val message = mock(classOf[AmqpMessage])
    val payload = "<test></test>"
    val props = new MessageProperties

    props.setDeliveryTag(1L)
    props.setContentType("text/plain")
    props.setContentEncoding("UTF-8")
    when(message.getMessageProperties).thenReturn(props)
    when(message.getBody).thenReturn(payload.getBytes())

    val listener = new IngressListener
    listener.outputChannel = outputChannel
    listener.errorChannel = errorChannel
    listener.onMessage(message, channel)

    // ack's should not be sent synchronously
    verify(channel, never()).basicAck(anyLong(), anyBoolean())
    verify(errorChannel, never()).send(anyObject())
    val outArgument = ArgumentCaptor.forClass(classOf[Message[_]])
    verify(outputChannel).send(outArgument.capture())
    val result = outArgument.getValue.getPayload.asInstanceOf[DOMSource]
    val stringResult = new String(XmlConverter.toBytes(result))
    XML.loadString(stringResult) should be (XML.loadString(payload))
  }
  
  it should "send errors to the error channel" in {
    val outputChannel = mock(classOf[MessageChannel])
    val errorChannel = mock(classOf[MessageChannel])
    val channel = mock(classOf[Channel])
    val message = mock(classOf[AmqpMessage])
    val payload = "TEST"
    val props = new MessageProperties

    props.setDeliveryTag(1L)
    props.setContentType("text/plain")
    props.setContentEncoding("UTF-8")
    when(message.getMessageProperties).thenReturn(props)
    when(message.getBody).thenReturn(payload.getBytes())
    when(outputChannel.send(anyObject())).thenThrow(new RuntimeException("Message forwarding failed"))

    val listener = new IngressListener
    listener.outputChannel = outputChannel
    listener.errorChannel = errorChannel
    listener.onMessage(message, channel)

    // ack's should not be sent synchronously
    verify(channel, never()).basicAck(anyLong(), anyBoolean())
    verify(errorChannel).send(anyObject())
  }

  it should "add timestamp header" in {
    val outputChannel = mock(classOf[MessageChannel])
    val channel = mock(classOf[Channel])
    val message = mock(classOf[AmqpMessage])
    val payload = "<test></test>"
    val tag = 1234L
    val props = new MessageProperties

    props.setDeliveryTag(tag)
    props.setContentType("text/plain")
    props.setContentEncoding("UTF-8")
    when(message.getMessageProperties).thenReturn(props)
    when(message.getBody).thenReturn(payload.getBytes)

    val listener = new IngressListener
    listener.outputChannel = outputChannel
    listener.onMessage(message, channel)

    // ack's should not be sent synchronously
    verify(channel, never()).basicAck(anyLong(), anyBoolean())
    val outArgument = ArgumentCaptor.forClass(classOf[Message[_]])
    verify(outputChannel).send(outArgument.capture())
    val header = outArgument.getValue.getHeaders.get(TranzoomHeaders.HEADER_INGRESS_TIMESTAMP).toString
    header should fullyMatch regex """\d+"""
  }
}
