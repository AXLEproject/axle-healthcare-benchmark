package net.mgrid.messaging.integration

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

/**
 * Integration tests assume running environment. The ingress integration
 * test requires a rabbitmq broker running with admin http interface on port
 * 15672 (default).
 */
class IngressSpec extends FlatSpec with Matchers with BeforeAndAfter {
  
  import IngressSpec._
  
  initBroker
  
  before {
    withChannel { channel =>
      // purge all queues
      List("ingress-fhir", "ingress-hl7v3", "dlx-errors", "dlx-ingress", "dlx-transform", "transform-sql", 
          "transform-hl7v3", "errors-ingress", "errors-transform", "errors-sql", "pond-seq", "unrouted") foreach (channel.queuePurge(_))
    }
  }
  
  "Ingress" should "nack messages when unexpected exceptions occur" in {
    
    val configFiles = Array("/META-INF/mgrid/messaging/tranzoom-ingress.xml")
    val ac = new ClassPathXmlApplicationContext(configFiles, IngressSpec.getClass)
    
    // stop and detach outbound adapter (we want to replace it with our test handler)
    val oa = ac.getBean("transformOutboundAdapter").asInstanceOf[EventDrivenConsumer]
    oa.stop()
    
    val tc = ac.getBean("toTransformersChannel").asInstanceOf[ExecutorChannel]
    
    // throw exception in different thread (i.e. handled by singleTaskExecutor)
    tc.subscribe(new MessageHandler {
      def handleMessage(message: Message[_]): Unit = throw new Exception
    })
    
    publish("some.fhir.message", """<Organization xmlns="http://hl7.org/fhir"></Organization>""")
    
    queueSize("transform-hl7v3") should be (0)
    queueSize("ingress-fhir") should be (1)
    
  }

}

object IngressSpec {
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