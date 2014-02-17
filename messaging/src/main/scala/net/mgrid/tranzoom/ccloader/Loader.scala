/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.tranzoom.ccloader

import java.util.Properties
import scala.beans.BeanProperty
import scala.collection.JavaConverters.asScalaBufferConverter
import org.apache.commons.dbcp.ConnectionFactory
import org.apache.commons.dbcp.DriverManagerConnectionFactory
import org.apache.commons.dbcp.PoolableConnectionFactory
import org.apache.commons.dbcp.PoolingDataSource
import org.apache.commons.pool.impl.GenericObjectPool
import org.slf4j.LoggerFactory
import org.springframework.integration.Message
import org.springframework.integration.MessageChannel
import javax.sql.DataSource
import net.mgrid.tranzoom.error.ErrorUtils
import net.mgrid.tranzoom.rabbitmq.PublishConfirmListener
import net.mgrid.tranzoom.TranzoomHeaders
import net.mgrid.tranzoom.rabbitmq.MessageListener
import scala.util.Try
import scala.util.Failure
import scala.util.Success
import javax.annotation.PostConstruct
import javax.annotation.PreDestroy
import java.sql.Connection
import scala.collection.JavaConverters._
import scala.collection.mutable.Buffer
import org.springframework.amqp.rabbit.core.RabbitTemplate
import org.springframework.amqp.rabbit.connection.{ ConnectionFactory => RabbitConnectionFactory }
import com.rabbitmq.client.Channel
import com.rabbitmq.client.AMQP

/**
 * Load SQL in database.
 *
 * Receives a configurable number of messages from the aggregator and groups them in
 * a single transaction for more efficient context conduction.
 */
class Loader {

  import Loader._
  import MessageListener.SourceRef

  @BeanProperty var pondHost: String = _
  @BeanProperty var pondPort: String = _
  @BeanProperty var pondDatabase: String = _
  @BeanProperty var pondUser: String = _
  @BeanProperty var lakeHost: String = _
  @BeanProperty var lakePort: String = _
  @BeanProperty var lakeDatabase: String = _
  @BeanProperty var lakeUser: String = _
  @BeanProperty var failedGroupChannel: MessageChannel = _
  @BeanProperty var errorChannel: MessageChannel = _
  @BeanProperty var confirmListener: PublishConfirmListener = _
  @BeanProperty var rabbitConnectionFactory: RabbitConnectionFactory = _

  private lazy val dataSource = newDatasource(s"jdbc:postgresql://$pondHost:$pondPort/$pondDatabase?user=$pondUser")

  private val PondSequence = """([-0-9]+):([-0-9]+)""".r

  @PostConstruct
  def start: Unit =
    withDatabaseConnection { conn =>
      withRabbitChannel { channel =>

        Option(channel.basicGet("pond-seq", false)) match {
          case Some(response) =>
            val PondSequence(start, end) = new String(response.getBody())

            if (logger.isDebugEnabled()) {
              logger.debug(s"Received pond sequence range [$start:$end] from broker, now tell the database")
            }

            val result = Try {
              query(conn, s"SELECT pond_setseq('$start:$end')")
            } map { // successfully set sequence; ack message
              _ => channel.basicAck(response.getEnvelope().getDeliveryTag(), false /*multiple*/ )
            } recover { // return sequence to broker on fail
              case ex: Throwable => channel.basicReject(response.getEnvelope().getDeliveryTag(), true /*requeue*/ )
            }

            result.get // throws exception on fail

          case None =>
            logger.error("No sequence range available for pond")
            throw new Exception("No sequence range available for pond")
        }
      }
    }

  @PreDestroy
  def stop: Unit =
    withDatabaseConnection { conn =>
      withRabbitChannel { channel =>
        
        if (logger.isDebugEnabled()) {
          logger.debug("Stopping loader; return available sequence range to broker")
        }
        
        val stmt = conn.createStatement()
        val rs = stmt.executeQuery(s"SELECT pond_retseq()")
        if (rs.next()) {
          val PondSequence(start, end) = rs.getString("pond_retseq")
          channel.basicPublish("sequencer", "pond", true /*mandatory*/ , false /*immediate*/ , null /*props*/ , s"$start:$end".getBytes())
        }
      }
    }

  /**
   * Load SQL message group in the data pond and upload to the data lake.
   *
   * On error, send all messages to the configured failed group channel.
   *
   * @param message Message containing the SQL message group
   */
  def loadGroup(group: Message[java.util.List[Message[String]]]): Unit = {
    val messages = group.getPayload.asScala
    load(messages) { ex =>
      logger.info(s"Forward messages to failed group channel.", ex)
      messages.foreach(failedGroupChannel.send(_))
    }
  }

  /**
   * Load SQL message in the data pond and upload to the data lake.
   *
   * On error, send error message to the error channel.
   *
   * @param message Message with a SQL payload
   */
  def loadSingle(message: Message[String]): Unit = load(Buffer(message)) { ex =>
    logger.info(s"Put reason on error queue.", ex)
    val ref = message.getHeaders.get(TranzoomHeaders.HEADER_SOURCE_REF).asInstanceOf[SourceRef]
    val errorMessage = ErrorUtils.errorMessage(ErrorUtils.ERROR_TYPE_VALIDATION, ex.getMessage, ref)
    errorChannel.send(errorMessage)
  }

  private def load(messages: Buffer[Message[String]])(txFail: Throwable => Unit): Unit = withDatabaseConnection { conn =>
    val loadStart = System.currentTimeMillis

    if (logger.isDebugEnabled) {
      logger.debug(s"Start load ${messages.size} messages on time $loadStart")
    }

    Try { // commit messages to data pond

      messages foreach { m => query(conn, m.getPayload) }
      conn.commit()

    } map { // upload to data lake

      import sys.process._

      _ => s"./loader-tools/pond_upload.sh -n $pondDatabase -H $lakeHost -N $lakeDatabase -U $lakeUser".!!

    } map { // commit and upload successful

      _ =>
        messages.foreach(confirmListener.deliverConfirm(_))

        if (logger.isDebugEnabled()) {
          val loadEnd = System.currentTimeMillis
          messages.foreach { m =>
            val ingressTimestamp = m.getHeaders.get("tz-ingress-timestamp")
            val txDelta = loadEnd - loadStart
            logger.debug(s"Loading complete: ingress time $ingressTimestamp loading end time $loadEnd, load time $txDelta")
          }
        }

    } recover { // handle fail

      case ex: Throwable =>
        logger.info(s"Exception during loading: ${ex.getMessage}, rollback transaction, empty pond and handle fail.", ex)
        conn.rollback()
        query(conn, "SELECT pond_empty()")
        txFail(ex)

    }

  }

  private def withDatabaseConnection[A](f: Connection => A): A = {
    val conn = dataSource.getConnection()
    try {
      f(conn)
    } finally {
      conn.close()
    }
  }

  private def withRabbitChannel[A](f: Channel => A): A = {
    val conn = rabbitConnectionFactory.createConnection()
    val channel = conn.createChannel(false)
    try {
      f(channel)
    } finally {
      channel.close()
      conn.close()
    }
  }

  private def query(conn: Connection, sql: String): Unit = {
    val s = conn.createStatement()
    s.execute(sql)
  }
}

/**
 * Helpers and database connection pooling.
 */
private object Loader {
  import org.apache.commons.pool.impl.GenericObjectPool
  import org.apache.commons.dbcp.PoolableConnectionFactory
  import org.apache.commons.dbcp.DriverManagerConnectionFactory
  import org.apache.commons.dbcp.PoolingDataSource
  import org.apache.commons.dbcp.ConnectionFactory
  import java.util.Properties

  Class.forName("org.postgresql.Driver")

  private val logger = LoggerFactory.getLogger(Loader.getClass)

  private def newDatasource(jdbcUri: String): DataSource = {
    val connPool = new GenericObjectPool()
    val connFactory: ConnectionFactory = new DriverManagerConnectionFactory(jdbcUri, new Properties())
    val poolableConnectionFactory = new PoolableConnectionFactory(connFactory, connPool, null /*stmtPoolFactory*/ , null /*validationQuery*/ , false /*defaultReadOnly*/ , false /*defaultAutoCommit*/ )

    new PoolingDataSource(connPool)
  }

}
