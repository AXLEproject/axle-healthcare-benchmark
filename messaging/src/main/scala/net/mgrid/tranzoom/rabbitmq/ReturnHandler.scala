package net.mgrid.tranzoom.rabbitmq

import org.springframework.amqp.core.Message
import org.springframework.amqp.rabbit.core.RabbitTemplate
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.beans.factory.annotation.Required
import net.mgrid.tranzoom.error.TranzoomErrorHandler
import org.springframework.integration.support.MessageBuilder
import net.mgrid.tranzoom.error.ErrorUtils

class RabbitReturnHandler extends RabbitTemplate.ReturnCallback {
  
  @Autowired @Required
  var errorHandler: TranzoomErrorHandler = _
  
  override def returnedMessage(message: Message, replyCode: Int, replyText: String, exchange: String, routingKey: String): Unit = {
    val m = MessageBuilder.withPayload(new String(message.getBody())).build()
    errorHandler.error(m, ErrorUtils.ERROR_TYPE_INTERNAL, s"Upstream broker could not route message: $replyText")
  }
  
}