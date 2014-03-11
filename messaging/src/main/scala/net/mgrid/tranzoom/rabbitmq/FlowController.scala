package net.mgrid.tranzoom.rabbitmq

import scala.beans.BeanProperty
import org.slf4j.LoggerFactory
import org.springframework.integration.Message
import com.rabbitmq.client.Channel
import org.springframework.beans.factory.annotation.Required
import org.springframework.amqp.rabbit.connection.ConnectionFactory
import javax.annotation.Resource
import org.springframework.integration.annotation.ServiceActivator
import org.springframework.integration.MessageChannel
import org.springframework.beans.factory.annotation.Autowired
import net.mgrid.tranzoom.error.ErrorHandler
import java.util.concurrent.Executor
import scala.concurrent._
import scala.concurrent.duration._

private case class FlowState(flowActive: Boolean, readyMessages: Seq[Message[_]])

/**
 * Watch total message count in queues, cache message if it exceeds a threshold.
 *
 * Informs all configured [[FlowController]]s whether the total message count of the
 * watched queues is above the threshold or not.
 */
class FlowController extends RabbitResourceProvider with RabbitUtils {

  import FlowController._
  import scala.collection.JavaConversions._

  @BeanProperty @Required
  var outputChannel: MessageChannel = _

  @BeanProperty
  var queues: java.util.List[String] = List()

  @BeanProperty
  var flowThreshold: Int = 0

  @Resource(name = "publishConnectionFactory") @Required
  var rabbitFactory: ConnectionFactory = _

  @Autowired @Required
  var errorHandler: ErrorHandler = _

  private implicit var rabbitExecutorService: ExecutionContextExecutor = _

  private var lastMessageCount: Int = 0

  private val messageCache = scala.collection.mutable.Queue[Message[_]]()

  @Required
  def setRabbitExecutor(executor: Executor): Unit =
    rabbitExecutorService = ExecutionContext.fromExecutor(executor)

  @ServiceActivator
  def send(message: Message[_]): Message[_] = accept(message).orNull

  def checkFlow(): Unit = {
    val count = countMessages
    synchronized {
      lastMessageCount = count
      val state = flowState()

      if (logger.isDebugEnabled()) {
        val qList = queues.mkString(",")
        val FlowState(_, cache) = state
        logger.debug(s"Watched queues: $qList, message count: $lastMessageCount, threshold: $flowThreshold, cache size: ${cache.size}, $state")
      }

      state

    } match {
      case FlowState(active, cache) if active => flushCache(cache)
      case _ => // nothing to be done
    }
  }

  private def accept(message: Message[_]): Option[Message[_]] = synchronized {
    flowState() match {
      case FlowState(active, cache) if active => Some(cache)
      case _ => {
        messageCache.enqueue(message)
        None
      }
    }
  } map { cache =>
    flushCache(cache)
    message
  }

  private def flushCache(cache: Seq[Message[_]]): Unit =
    try {
      cache foreach (outputChannel.send(_))
    } catch {
      case ex: Throwable =>
        logger.error(s"Unexpected error during flushing flow control cache: ${ex.getMessage}", ex)
        errorHandler.fatal(ex)
    }

  private def flowState(): FlowState =
    if (lastMessageCount < flowThreshold) {
      FlowState(true, messageCache.dequeueAll(_ => true))
    } else {
      FlowState(false, Seq())
    }

  /**
   * Ask the broker for the message count. Because of the use of publisher confirms we make sure that
   * all broker communication through the same connection factory happens in a single thread,
   * see the implicit execution context defined in this class.
   * 
   * We use a blocking Await.result to make sure the result is returned on the calling thread.
   */
  private def countMessages: Int = Await.result(future {
    withRabbitChannel { channel =>
      queues.toList.foldLeft(0)(_ + channel.queueDeclarePassive(_).getMessageCount())
    }
  }, Duration(1, SECONDS))

  def rabbitConnectionFactory = rabbitFactory
}

object FlowController {
  private val logger = LoggerFactory.getLogger(FlowController.getClass)
}