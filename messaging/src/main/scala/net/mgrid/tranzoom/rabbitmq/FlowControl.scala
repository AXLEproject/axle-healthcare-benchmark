package net.mgrid.tranzoom.rabbitmq

import scala.beans.BeanProperty
import scala.collection.JavaConversions.asScalaBuffer
import scala.collection.JavaConversions.seqAsJavaList
import org.slf4j.LoggerFactory
import org.springframework.amqp.rabbit.connection.ConnectionFactory
import org.springframework.beans.factory.annotation.Required
import org.springframework.transaction.support.TransactionSynchronization
import org.springframework.transaction.support.TransactionSynchronizationAdapter
import org.springframework.transaction.support.TransactionSynchronizationManager
import javax.annotation.Resource
import org.aopalliance.intercept.MethodInvocation
import org.aopalliance.intercept.MethodInterceptor

trait FlowController {
  def state(active: Boolean): Unit
}

class FlowControlSupervisor extends RabbitResourceProvider with RabbitUtils {

  import scala.collection.JavaConversions._

  @BeanProperty @Required
  var flowController: FlowController = _

  @BeanProperty
  var queues: java.util.List[String] = List()

  @BeanProperty
  var flowThreshold: Int = 0

  @Resource(name = "publishConnectionFactory") @Required
  var rabbitFactory: ConnectionFactory = _

  private val logger = LoggerFactory.getLogger(classOf[FlowControlSupervisor])

  def checkFlow(): Unit = {
    val count = countMessages()
    logger.info(s"Checking message count $count with set threshold $flowThreshold")
    flowController.state(count < flowThreshold)
  }

  private def countMessages(): Int = withRabbitChannel { channel =>
    queues.toList.foldLeft(0)(_ + channel.queueDeclarePassive(_).getMessageCount())
  }

  def rabbitConnectionFactory = rabbitFactory

}

class BlockingFlowController extends TransactionSynchronizationAdapter with FlowController {

  @BeanProperty
  var flowPeriod: Int = 5000

  private val logger = LoggerFactory.getLogger(classOf[BlockingFlowController])

  @volatile private var shouldBlock = false

  override def afterCompletion(status: Int): Unit = {
    if (logger.isDebugEnabled()) {
      val t = Thread.currentThread().getName()
      logger.debug(s"Transaction afterCompletion callback called for thread $t")
    }

    blockWhileInactive()
  }

  override def state(active: Boolean): Unit = (shouldBlock = !active)

  private def blockWhileInactive(): Unit = {
    while (shouldBlock) {
      if (logger.isDebugEnabled()) {
        val t = Thread.currentThread().getName()
        logger.debug(s"Flow is inactive, block current thread $t")
      }
      Thread.sleep(flowPeriod)
    }
  }

  override def toString(): String = s"BlockingFlowController[flowPeriod=$flowPeriod, shouldBlock=$shouldBlock]"

}
