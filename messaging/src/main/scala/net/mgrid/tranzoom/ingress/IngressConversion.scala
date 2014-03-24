package net.mgrid.tranzoom.ingress

import org.springframework.amqp.core.Message
import org.springframework.amqp.core.MessageProperties
import org.springframework.amqp.support.converter.MessageConverter
import org.springframework.integration.amqp.support.DefaultAmqpHeaderMapper

import net.mgrid.tranzoom.TranzoomHeaders
import net.mgrid.tranzoom.ingress.xml.XmlConverter

class IngressMessageConverter extends MessageConverter {
  
  override def fromMessage(message: Message): Object =
    XmlConverter.toDOMSource(message.getBody())
  
  override def toMessage(obj: Object, messageProperties: MessageProperties): Message =
    throw new UnsupportedOperationException()
    
}

class IngressHeaderMapper extends DefaultAmqpHeaderMapper {
  
  override def toHeadersFromRequest(source: MessageProperties): java.util.Map[String, Object] = {
    val result = super.toHeadersFromRequest(source)
    result.put(TranzoomHeaders.HEADER_INGRESS_TIMESTAMP, String.valueOf(System.currentTimeMillis()))
    result
  }
  
}