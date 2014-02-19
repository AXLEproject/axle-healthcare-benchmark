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
import sys.process._

/**
 * Load SQL in database.
 *
 * Receives a configurable number of messages from the aggregator and groups them in
 * a single transaction for more efficient context conduction.
 */
class Loader {

  import Loader._
  import MessageListener.SourceRef

  @BeanProperty var pondUploadScript: String = "../pond/pond_upload.sh"
  @BeanProperty var pondHost: String = "localhost"
  @BeanProperty var pondPort: String = "5432"
  @BeanProperty var pondDatabase: String = "pond"
  @BeanProperty var pondUser: String = System.getProperty("user.name")
  @BeanProperty var lakeHost: String = "localhost"
  @BeanProperty var lakePort: String = "5432"
  @BeanProperty var lakeDatabase: String = "lake"
  @BeanProperty var lakeUser: String = System.getProperty("user.name")
  @BeanProperty var failedGroupChannel: MessageChannel = _
  @BeanProperty var errorChannel: MessageChannel = _
  @BeanProperty var confirmListener: PublishConfirmListener = _
  @BeanProperty var rabbitConnectionFactory: RabbitConnectionFactory = _

  private lazy val dataSource = newDatasource(s"jdbc:postgresql://$pondHost:$pondPort/$pondDatabase?user=$pondUser")

  private val PondSequence = """([-0-9]+):([-0-9]+)""".r

  @PostConstruct
  def start: Unit = withDatabaseConnection { conn =>
    singleQuery[Boolean](conn, "SELECT pond_ready()") match {
      case Some(isReady) if isReady => {
        logger.info("Pond ready, no need to obtain sequence from broker")
      }
      case _ => withRabbitChannel { channel =>

        Option(channel.basicGet("pond-seq", false)) match {
          case Some(response) =>
            val PondSequence(start, end) = new String(response.getBody())

            if (logger.isDebugEnabled()) {
              logger.debug(s"Received pond sequence range [$start:$end] from broker, now tell the database")
            }

            val result = Try {
              val hostname = "hostname --fqdn".!!.filter(_ >= ' ') // filter out all control characters
              singleQuery(conn, s"SELECT pond_init('$start:$end', '$hostname')")
            } map { // successfully set sequence; ack message
              _ => channel.basicAck(response.getEnvelope().getDeliveryTag(), false /*multiple*/ )
            } recover { // return sequence to broker on fail
              case ex: Throwable => 
                logger.warn("Could not initialize pond", ex)
                channel.basicReject(response.getEnvelope().getDeliveryTag(), true /*requeue*/ )
            }

            result.get // throws exception on fail

          case None =>
            logger.error("No sequence range available for pond")
            throw new Exception("No sequence range available for pond")
        }
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

        singleQuery[String](conn, s"SELECT pond_retseq()") map { range =>
          channel.basicPublish("sequencer", "pond", true /*mandatory*/ , false /*immediate*/ , null /*props*/ , range.getBytes())
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

      _ => s"$pondUploadScript -n $pondDatabase -H $lakeHost -N $lakeDatabase -U $lakeUser".!!

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
        quietly(conn.rollback())
        quietly(singleQuery(conn, "SELECT pond_empty()"))
        quietly(txFail(ex))

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

  private def singleQuery[T](conn: Connection, sql: String): Option[T] = {
    val result = query(conn, sql)
    conn.commit()
    result
  }

  private def query[T](conn: Connection, sql: String): Option[T] = {
    val s = conn.createStatement()
    if (s.execute(sql)) {
      val rs = s.getResultSet()
      if (rs.next()) {
        Some(rs.getObject(1).asInstanceOf[T])
      } else {
        None
      }
    } else {
      None
    }
  }

  private def quietly[T](f: => T): Unit = {
    try {
      f
    } catch {
      case _: Throwable => /* ssst */
    }
  }
}

/**
 * Helpers and database connection pooling.
 */
object Loader {
  import org.apache.commons.pool.impl.GenericObjectPool
  import org.apache.commons.dbcp.PoolableConnectionFactory
  import org.apache.commons.dbcp.DriverManagerConnectionFactory
  import org.apache.commons.dbcp.PoolingDataSource
  import org.apache.commons.dbcp.ConnectionFactory
  import java.util.Properties

  Class.forName("org.postgresql.Driver")

  private val logger = LoggerFactory.getLogger(Loader.getClass)

  def newDatasource(jdbcUri: String): DataSource = {
    val connPool = new GenericObjectPool()
    val connFactory: ConnectionFactory = new DriverManagerConnectionFactory(jdbcUri, new Properties())
    val poolableConnectionFactory = new PoolableConnectionFactory(connFactory, connPool, null /*stmtPoolFactory*/ , null /*validationQuery*/ , false /*defaultReadOnly*/ , false /*defaultAutoCommit*/ )

    new PoolingDataSource(connPool)
  }

}
