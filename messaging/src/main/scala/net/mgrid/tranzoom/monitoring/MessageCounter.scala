package net.mgrid.tranzoom.monitoring

import java.util.concurrent.atomic.AtomicInteger
import scala.beans.BeanProperty
import org.springframework.amqp.rabbit.core.RabbitTemplate
import org.springframework.beans.factory.annotation.Required
import org.springframework.integration.Message
import org.springframework.integration.MessageChannel
import org.springframework.integration.channel.interceptor.ChannelInterceptorAdapter
import org.springframework.amqp.core.{Message => RabbitMessage}
import net.liftweb.json.Serialization
import org.springframework.amqp.core.MessageProperties
import net.liftweb.json.NoTypeHints
import org.slf4j.LoggerFactory
import java.util.concurrent.atomic.AtomicLong
import java.util.UUID

private case class MonitoringUpdate(processType: String, processName: String, count: Int, size: Long)

class MessageCounter extends ChannelInterceptorAdapter {
  
  import scala.collection.JavaConversions._
  
  private val logger = LoggerFactory.getLogger(classOf[MessageCounter])
  
  private implicit val formats = Serialization.formats(NoTypeHints)
  
  @BeanProperty @Required
  var processType: String = _
  
  @BeanProperty
  var processName: String = UUID.randomUUID.toString
  
  @BeanProperty @Required
  var rabbitTemplate: RabbitTemplate = _
  
  private val counter = new AtomicInteger()
  private val bytes = new AtomicLong()
  
  override def postSend(message: Message[_], channel: MessageChannel, sent: Boolean): Unit = {
    if (sent) {
      message.getPayload() match {
        case lst: java.util.List[_] => lst.toList.foreach(m => updateCounters(m.asInstanceOf[Message[_]]))
        case _ => updateCounters(message)
      }
    }
  }
  
  def publish(): Unit = {
    val count = counter.getAndSet(0)
    val size = bytes.getAndSet(0)
    val payload = Serialization.write(MonitoringUpdate(processType, processName, count, size))
    val message = new RabbitMessage(payload.getBytes(), new MessageProperties())
    
    logger.info(s"Publishing monitoring update $payload to broker")
    rabbitTemplate.send("monitor", "monitoring", message)
  }
  
  private def updateCounters(message: Message[_]): Unit = {
    val numBytes = message.getPayload() match {
        case ba: Array[Byte] => ba.length
        case s: String => s.length // not accurate but good enough (e.g. for UTF-8)
        case c @ _ =>
          logger.warn(s"Unable to determine payload size for $c")
          0
      }
      counter.incrementAndGet()
      bytes.getAndAdd(numBytes)
  }

}

