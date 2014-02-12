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

/**
 * Load SQL in database.
 *
 * Receives a configurable number of messages from the aggregator and groups them in
 * a single transaction for more efficient context conduction.
 */
class Loader(connectURI: String) {

  import Loader._
  import MessageListener.SourceRef

  @BeanProperty
  var failedGroupChannel: MessageChannel = _

  @BeanProperty
  var errorChannel: MessageChannel = _

  @BeanProperty
  var confirmListener: PublishConfirmListener = _

  private val datasource = newDatasource(connectURI)

  /**
   * Load SQL message group in the database.
   *
   * After a successful commit, send upstream confirm that the database system has taken over
   * the responsibility of the message.
   *
   * On error, send a message to the configured failedGroupChannel.
   *
   * @param message The message with a SQL message group
   */
  def load(group: Message[java.util.List[Message[String]]]): Unit = {
    import scala.collection.JavaConverters._

    Try(datasource.getConnection()) match {
      case Success(conn) => {
        val messages = group.getPayload.asScala
        val txStart = System.currentTimeMillis

        if (logger.isDebugEnabled) {
          logger.debug(s"Start loading of group with ${messages.size} messages on time $txStart")
        }

        try {
          messages.foreach { m =>
            val q = m.getPayload
            val stmt = conn.createStatement()
            stmt.execute(q)
          }

          if (logger.isDebugEnabled) {
            logger.debug(s"Committing group with ${messages.size} messages")
          }

          conn.commit()
          messages.foreach(confirmListener.deliverConfirm(_))

          if (logger.isDebugEnabled()) {
            val txEnd = System.currentTimeMillis
            messages.foreach { m =>
              val ingressTimestamp = m.getHeaders.get("tz-ingress-timestamp")
              val txDelta = txEnd - txStart
              logger.debug(s"Loading complete: ingress time $ingressTimestamp loading end time $txEnd, load time $txDelta")
            }
          }
        } catch {
          case ex: Throwable => {
            logger.info(s"Transaction throwed exception: ${ex.getMessage}, rollback and forward to failed group channel.", ex)
            conn.rollback()
            messages.foreach(failedGroupChannel.send(_))
          }
        } finally {
          conn.close()
        }
      }
      case Failure(ex) => {
        logger.info(s"Could not get a database connection, put reason on error queue for each message in the group.", ex)

        val messages = group.getPayload.asScala
        messages.foreach { m =>
          val ref = m.getHeaders.get(TranzoomHeaders.HEADER_SOURCE_REF).asInstanceOf[SourceRef]
          val errorMessage = ErrorUtils.errorMessage(ErrorUtils.ERROR_TYPE_VALIDATION, ex.getMessage, ref)
          errorChannel.send(errorMessage)
        }
      }
    }

  }

  /**
   * Load a single SQL message in the database.
   * 
   * For example, this method can be used as a fall back when loading a message group fails.
   *
   * @param message The message with a SQL payload
   */
  def loadSingle(message: Message[String]): Unit = {

    Try(datasource.getConnection()) match {
      case Success(conn) => {
        try {
          val stmt = conn.createStatement()
          stmt.execute(message.getPayload)
          conn.commit()

          if (logger.isDebugEnabled) {
            val ts = System.currentTimeMillis
            val ingressTimestamp = message.getHeaders.get("tz-ingress-timestamp")
            logger.debug(s"Staging complete: ingress time $ingressTimestamp staging time $ts")
          }

          confirmListener.deliverConfirm(message)

        } catch {
          case ex: Throwable => {
            logger.info(s"Single query throwed exception for $message: ${ex.getMessage}, put reason on error queue.", ex)
            conn.rollback()

            val ref = message.getHeaders.get(TranzoomHeaders.HEADER_SOURCE_REF) match {
              case ref: SourceRef => ref
            }

            val errorMessage = ErrorUtils.errorMessage(ErrorUtils.ERROR_TYPE_VALIDATION, ex.getMessage, ref)
            errorChannel.send(errorMessage)
          }
        } finally {
          conn.close()
        }
      }
      case Failure(ex) => {
        logger.info(s"Could not get a database connection, put reason on error queue.", ex)

        val ref = message.getHeaders.get(TranzoomHeaders.HEADER_SOURCE_REF) match {
          case ref: SourceRef => ref
        }

        val errorMessage = ErrorUtils.errorMessage(ErrorUtils.ERROR_TYPE_VALIDATION, ex.getMessage, ref)
        errorChannel.send(errorMessage)
      }
    }
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

  private def newDatasource(connectURI: String): DataSource = {
    val connPool = new GenericObjectPool()
    val connFactory: ConnectionFactory = new DriverManagerConnectionFactory(connectURI, new Properties())
    val poolableConnectionFactory = new PoolableConnectionFactory(connFactory, connPool, null /*stmtPoolFactory*/ , null /*validationQuery*/ , false /*defaultReadOnly*/ , false /*defaultAutoCommit*/ )

    new PoolingDataSource(connPool)
  }
}
