package net.mgrid.messaging.end2end

import org.scalatest.Matchers
import org.scalatest.FlatSpec
import net.mgrid.messaging.publish.PublishDir
import com.rabbitmq.client.ConnectionFactory
import com.rabbitmq.client.Channel
import com.rabbitmq.client.Connection
import com.rabbitmq.client.MessageProperties
import org.springframework.context.support.ClassPathXmlApplicationContext
import org.scalatest.BeforeAndAfter
import org.springframework.integration.endpoint.EventDrivenConsumer
import org.springframework.integration.channel.ExecutorChannel
import org.springframework.integration.core.MessageHandler
import org.springframework.integration.Message

class TranzoomSpec extends FlatSpec with Matchers with BeforeAndAfter {
  
  import TranzoomSpec._
  
  initBroker
  
  before {
    withChannel { channel =>
      // purge all queues
      List("ingress-fhir", "ingress-hl7v3", "dlx-errors", "dlx-ingress", "dlx-transform", "transform-sql", 
          "transform-hl7v3", "errors-ingress", "errors-transform", "errors-sql", "pond-seq", "unrouted") foreach (channel.queuePurge(_))
    }
  }
  
  "Tranzoom" should "work" in {
    
  }

}

object TranzoomSpec {
  import sys.process._
  
  val conn = {
    val factory = new ConnectionFactory
    factory.setUsername("admin")
    factory.setPassword("tr4nz00m")
    factory.setVirtualHost("/messaging")
    factory.setHost("localhost")
    factory.setPort(5672)
    factory.newConnection()
  }
  
  def initBroker = {
    """curl -i -u guest:guest -H "content-type:application/json" -XPOST http://localhost:15672/api/definitions
      -d @config/rabbitmq_broker_definitions.json""".!!
  }
  
  def publish(routingKey: String, payload: String) =
    withChannel ( _.basicPublish("ingress", routingKey, MessageProperties.TEXT_PLAIN, payload.getBytes()))
    
  def queueSize(queue: String): Int =
    withChannel (_.queueDeclarePassive(queue).getMessageCount())
  
  def withChannel[A](f: Channel => A): A = {
    val channel = conn.createChannel()
    try {
      f(channel)
    } finally {
      channel.close()
    }
  }
  
}