/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.tranzoom.ccloader

import scala.annotation.implicitNotFound
import scala.beans.BeanProperty
import scala.collection.JavaConversions.asScalaBuffer
import scala.sys.process.ProcessLogger
import scala.sys.process.stringToProcess
import scala.util.Try
import org.slf4j.LoggerFactory
import org.springframework.amqp.rabbit.connection.{ConnectionFactory => RabbitConnectionFactory}
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.beans.factory.annotation.Required
import org.springframework.integration.Message
import org.springframework.integration.annotation.ServiceActivator
import javax.annotation.PostConstruct
import javax.annotation.PreDestroy
import javax.annotation.Resource
import net.mgrid.tranzoom.error.TranzoomErrorHandler
import net.mgrid.tranzoom.error.ErrorUtils
import net.mgrid.tranzoom.rabbitmq.RabbitResourceProvider
import net.mgrid.tranzoom.rabbitmq.RabbitUtils
import net.mgrid.tranzoom.TranzoomHeaders

/**
 * Load SQL in database.
 *
 * Receives a configurable number of messages from the aggregator and groups them in
 * a single transaction towards the data pond for more efficient context conduction.
 * When successful, the tables are uploaded to the data lake.
 */
class Loader extends PondUtils with RabbitResourceProvider with RabbitUtils {

  import Loader._

  @BeanProperty @Required
  var pondUploadScript: String = _

  @BeanProperty
  var pondHost: String = "localhost"

  @BeanProperty
  var pondPort: String = "5432"

  @BeanProperty @Required
  var pondDatabase: String = _

  @BeanProperty
  var pondUser: String = System.getProperty("user.name")

  @BeanProperty
  var lakeHost: String = "localhost"

  @BeanProperty
  var lakePort: String = "5432"

  @BeanProperty @Required
  var lakeDatabase: String = _

  @BeanProperty
  var lakeUser: String = System.getProperty("user.name")

  @Autowired @Required
  var errorHandler: TranzoomErrorHandler = _

  @Resource(name="consumeConnectionFactory") @Required
  var rabbitFactory: RabbitConnectionFactory = _

  @PostConstruct
  def start: Unit = {
    logger.info(s"Starting loader $this, check if we need to initialize the pond")

    if (!pondReady()) {
      withRabbitChannel { implicit channel =>
        withPondSequence { seq =>
          logger.info(s"Received pond sequence [$seq] from broker, now initialize the pond")
          initPond(seq)
        }
      }
    }
  }

  @PreDestroy
  def stop: Unit = {
    logger.info("Stopping loader, reset pond")
    withRabbitChannel { implicit channel =>
      resetPond
    }
  }

  /**
   * Load SQL message group in the data pond and upload to the data lake.
   *
   * @param message Message containing the SQL message group
   */
  @ServiceActivator
  def loadGroup(group: Message[java.util.List[Message[String]]]): Unit = synchronized {
    import scala.collection.JavaConversions._
    val messages = group.getPayload().toList
    val loadStart = System.currentTimeMillis

    if (logger.isDebugEnabled) {
      logger.debug(s"Start load ${messages.size} messages on time $loadStart")
    }

    Try { // commit messages to data pond

      val txStart = System.currentTimeMillis()

      val numCommitted = commitToPond(messages)

      if (logger.isDebugEnabled()) {
        val txEnd = System.currentTimeMillis()
        val txDelta = txEnd - txStart
        logger.debug(s"Transaction finished, group size ${messages.size}, success $numCommitted, time $txDelta ms")
      }

    } map { // committed, upload to data lake

      _ =>
        val uploadStart = System.currentTimeMillis()
        val stdout = StringBuilder.newBuilder
        val stderr = StringBuilder.newBuilder
        val processLogger = ProcessLogger(out => stdout.append(s"$out\n"), err => stderr.append(s"$err\n"))

        val exitCode = s"$pondUploadScript -n $pondDatabase -u $pondUser -H $lakeHost -N $lakeDatabase -U $lakeUser -P $lakePort".!(processLogger)

        if (logger.isDebugEnabled()) {
          val uploadEnd = System.currentTimeMillis()
          val uploadDelta = uploadEnd - uploadStart
          logger.debug(s"Upload script finished, running time $uploadDelta ms, exit code $exitCode, stderr[${stderr.mkString}], stdout[${stdout.mkString}]")

          messages.headOption map { m =>
            val ingressTimestamp = m.getHeaders.get(TranzoomHeaders.HEADER_INGRESS_TIMESTAMP).asInstanceOf[String]
            val ingressStart = java.lang.Long.parseLong(ingressTimestamp)
            val loadDelta = uploadEnd - loadStart
            val total = uploadEnd - ingressStart
            logger.debug(s"Loading complete: ingress time $ingressTimestamp, total $total ms")
          }
        }

        if (exitCode != 0) {
          throw new Exception(s"Upload to data lake failed: ${stderr.mkString}")
        }

    } recover { // handle fail

      case ex: Throwable =>
        logger.info(s"Exception during loading: ${ex.getMessage}, report error for all messages in group and empty pond.", ex)
        messages foreach (m => errorHandler.error(m, ErrorUtils.ERROR_TYPE_INTERNAL, ex.getMessage))
        emptyPond()
    }

  }

  override def rabbitConnectionFactory = rabbitFactory

  override def toString: String = s"""
        |Loader[pondUploadScript=$pondUploadScript,
        |pondHost=$pondHost, pondPort=$pondPort, pondDatabase: $pondDatabase, pondUser: $pondUser,
        |lakeHost: $lakeHost, lakePort=$lakePort, lakeDatabase: $lakeDatabase, lakeUser: $lakeUser]
    """.stripMargin
}

object Loader {

  private val logger = LoggerFactory.getLogger(Loader.getClass)

}
