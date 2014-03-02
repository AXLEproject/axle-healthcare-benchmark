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
import org.springframework.amqp.rabbit.core.RabbitTemplate
import org.springframework.amqp.rabbit.connection.{ ConnectionFactory => RabbitConnectionFactory }
import com.rabbitmq.client.Channel
import com.rabbitmq.client.AMQP
import sys.process._
import net.mgrid.tranzoom.error.ErrorHandler
import org.springframework.integration.annotation.ServiceActivator
import org.springframework.beans.factory.annotation.Required
import org.springframework.beans.factory.annotation.Autowired
import java.sql.SQLException
import java.sql.Statement

/**
 * Load SQL in database.
 *
 * Receives a configurable number of messages from the aggregator and groups them in
 * a single transaction towards the data pond for more efficient context conduction.
 * When successful, the tables are uploaded to the data lake.
 */
class Loader {

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
  var confirmListener: PublishConfirmListener = _

  @Autowired @Required
  var rabbitConnectionFactory: RabbitConnectionFactory = _

  @Autowired @Required
  var errorHandler: ErrorHandler = _

  private lazy val dataSource = newDatasource(s"jdbc:postgresql://$pondHost:$pondPort/$pondDatabase?user=$pondUser")

  private lazy val hostname = "hostname --fqdn".!!.filter(_ >= ' ') // filter out all control characters

  @PostConstruct
  def start: Unit = {
    logger.info(s"Starting loader $this, check if we need to initialize the pond")

    withDatabaseConnection { implicit conn =>
      if (!pondReady) {
        withRabbitChannel { implicit channel =>
          withPondSequence { seq =>
            logger.info(s"Received pond sequence [$seq] from broker, now initialize the pond")
            initPond(seq)
          }
        }
      }
    }
  }

  @PreDestroy
  def stop: Unit = {
    logger.info("Stopping loader, reset pond")
    withDatabaseConnection { implicit conn =>
      withRabbitChannel { implicit channel =>
        resetPond
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
  @ServiceActivator
  def loadGroup(group: Message[java.util.List[Message[String]]]): Unit = synchronized {
    import scala.collection.JavaConversions._
    val messages = group.getPayload().toList

    withDatabaseConnection { implicit conn =>
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

        val uploadStart = System.currentTimeMillis()

        _ =>
          s"$pondUploadScript -n $pondDatabase -u $pondUser -H $lakeHost -N $lakeDatabase -U $lakeUser -P $lakePort".!!

          if (logger.isDebugEnabled()) {
            val uploadEnd = System.currentTimeMillis()
            val uploadDelta = uploadEnd - uploadStart
            logger.debug(s"Upload finished, total $uploadDelta ms")
          }

      } map { // uploaded, confirm to broker

        _ =>
          messages.foreach(confirmListener.deliverConfirm(_))

          if (logger.isDebugEnabled()) {
            val loadEnd = System.currentTimeMillis
            messages.headOption map { m =>
              val ingressTimestamp = m.getHeaders.get("tz-ingress-timestamp").asInstanceOf[String]
              val ingressStart = java.lang.Long.parseLong(ingressTimestamp)
              val loadDelta = loadEnd - loadStart
              val total = loadEnd - ingressStart
              logger.debug(s"Loading complete: ingress time $ingressTimestamp, total $total ms")
            }
          }

      } recover { // handle fail

        case ex: Throwable =>
          logger.info(s"Exception during loading: ${ex.getMessage}, report error for all messages in group and empty pond.", ex)
          messages foreach (m => errorHandler.error(m, ErrorUtils.ERROR_TYPE_INTERNAL, ex.getMessage))
          emptyPond
      }

    }
  }

  private def pondReady(implicit conn: Connection): Boolean =
    singleQuery[Boolean]("SELECT pond_ready()").getOrElse(false)

  private def withPondSequence[T](f: String => T)(implicit channel: Channel): T =
    Option(channel.basicGet("pond-seq", false)) match {
      case Some(response) =>
        try {
          val seq = new String(response.getBody())
          val result = f(seq)
          logger.info("Successfully setup pond sequence, ack message to broker")
          channel.basicAck(response.getEnvelope().getDeliveryTag(), false /*multiple*/ )
          result
        } catch {
          case ex: Throwable =>
            logger.warn("Exception during pond sequence handling")
            channel.basicReject(response.getEnvelope().getDeliveryTag(), true /*requeue*/ )
            throw ex
        }
      case None => throw new Exception("No pond sequence available from broker")
    }

  private def initPond(seq: String)(implicit conn: Connection): Unit =
    singleQuery(s"SELECT pond_init('$seq', '$hostname')")

  private def resetPond(implicit conn: Connection, channel: Channel): Unit =
    singleQuery[String](s"SELECT pond_retseq()") map { seq =>
      logger.info(s"Return sequence  $seq to broker")
      channel.basicPublish("sequencer", "pond", true /*mandatory*/ , false /*immediate*/ , null /*props*/ , seq.getBytes())
    }

  private def emptyPond(implicit conn: Connection): Unit = singleQuery("SELECT pond_empty()")

  /**
   * @return Number of messages that successfully committed
   */
  private def commitToPond(messages: List[Message[String]])(implicit conn: Connection): Int = {
    def queryOk(message: Message[String])(onFail: Throwable => Unit): Boolean = {
      val stmt = conn.createStatement()
      try {
        stmt.execute(message.getPayload)
        true
      } catch {
        case ex: SQLException =>
          onFail(ex)
          false
      } finally {
        quietly(stmt.close())
      }
    }

    messages partition (m => queryOk(m)(ex => errorHandler.error(m, ErrorUtils.ERROR_TYPE_VALIDATION, ex.getMessage))) match {
      case (Nil, _) =>
        // all messages failed
        quietly(conn.rollback())
        0
      case (_, Nil) =>
        // all messages successfully executed, we can commit
        conn.commit()
        messages.size
      case (successList, failList) =>
        // some messages failed, rollback and commit the succeeded messages
        quietly(conn.rollback())
        commitToPond(successList)
    }
  }

  private def withDatabaseConnection[A](f: Connection => A): A = {
    val conn = dataSource.getConnection()
    try {
      f(conn)
    } finally {
      quietly(conn.close())
    }
  }

  private def withRabbitChannel[A](f: Channel => A): A = {
    val conn = rabbitConnectionFactory.createConnection()
    val channel = conn.createChannel(false)
    try {
      f(channel)
    } finally {
      quietly(channel.close())
      quietly(conn.close())
    }
  }

  private def singleQuery[T](sql: String)(implicit conn: Connection): Option[T] = {
    def query[T](conn: Connection, sql: String): Option[T] = {
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

    val result = query(conn, sql)
    conn.commit()
    result
  }

  private def quietly[T](f: => T): Unit = {
    try {
      f
    } catch {
      case ex: Throwable => /* ssst */ logger.info(s"Quietly ignoring exception ${ex.getMessage}")
    }
  }

  override def toString: String = s"""
        |Loader[pondUploadScript=$pondUploadScript, 
        |pondHost=$pondHost, pondPort=$pondPort, pondDatabase: $pondDatabase, pondUser: $pondUser, 
        |lakeHost: $lakeHost, lakeDatabase: $lakeDatabase, lakeUser: $lakeUser]
    """.stripMargin
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

    //connPool.setMaxActive(1)
    //connPool.setMaxIdle(1)
    //connPool.setWhenExhaustedAction(GenericObjectPool.WHEN_EXHAUSTED_BLOCK)
    //connPool.setMaxWait(0)

    val connFactory: ConnectionFactory = new DriverManagerConnectionFactory(jdbcUri, new Properties())
    val poolableConnectionFactory = new PoolableConnectionFactory(connFactory, connPool, null /*stmtPoolFactory*/ , null /*validationQuery*/ , false /*defaultReadOnly*/ , false /*defaultAutoCommit*/ )

    new PoolingDataSource(connPool)
  }

}
