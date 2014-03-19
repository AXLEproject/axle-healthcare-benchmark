package net.mgrid.tranzoom.ingress

import net.mgrid.tranzoom.TranzoomHeaders
import net.mgrid.tranzoom.ingress.xml.XmlConverter
import org.springframework.integration.support.MessageBuilder
import org.springframework.amqp.core.Message
import org.springframework.amqp.core.MessageProperties
import org.springframework.amqp.support.converter.MessageConverter
import org.slf4j.LoggerFactory

class IngressMessageConverter extends MessageConverter {
  
  private val logger = LoggerFactory.getLogger(classOf[IngressMessageConverter])
  
  override def fromMessage(message: Message): Object = {
    logger.info(s"Received $message")
    XmlConverter.toDOMSource(message.getBody())
  }
  
  override def toMessage(obj: Object, messageProperties: MessageProperties): Message =
    throw new UnsupportedOperationException()
    
}
