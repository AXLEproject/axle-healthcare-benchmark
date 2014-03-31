/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.messaging.integration

import org.scalatest.Matchers
import org.scalatest.FlatSpec
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
import net.mgrid.messaging.testutils.RabbitUtils

/**
 * Integration tests assume running environment. The ingress integration
 * test requires a rabbitmq broker running with admin http interface on port
 * 15672 (default).
 */
class IngressIntegrationSpec extends FlatSpec with Matchers with BeforeAndAfter with RabbitUtils {
  
  initBroker
  
  before {
    withChannel { channel =>
      // purge all queues
      List("ingress-fhir", "ingress-hl7v3", "dlx-errors", "dlx-ingress", "dlx-transform", "transform-sql", 
          "transform-hl7v3", "errors-ingress", "errors-transform", "errors-sql", "pond-seq", "unrouted") foreach (channel.queuePurge(_))
    }
  }
  
  "Ingress" should "send messages to the error queue when an exception occurs [async task executor]" in {
    
    val configFiles = Array("/META-INF/mgrid/messaging/tranzoom-ingress.xml")
    val ac = new ClassPathXmlApplicationContext(configFiles, classOf[IngressIntegrationSpec])
    
    // stop and detach outbound adapter (we want to replace it with our test handler)
    val oa = ac.getBean("transformOutboundAdapter").asInstanceOf[EventDrivenConsumer]
    oa.stop()
    
    val tc = ac.getBean("toTransformersChannel").asInstanceOf[ExecutorChannel]
    
    // throw exception in different thread (i.e. handled by singleTaskExecutor)
    tc.subscribe(new MessageHandler {
      def handleMessage(message: Message[_]): Unit = throw new Exception("Random exception")
    })
    
    publish("ingress", "some.fhir.message", """<Organization xmlns="http://hl7.org/fhir"></Organization>""")
    
    // wait some time to allow message processing
    Thread.sleep(500)
    
    queueSize("ingress-fhir") should be (0)
    queueSize("transform-hl7v3") should be (0)
    queueSize("errors-ingress") should be (1)
    
  }

}

