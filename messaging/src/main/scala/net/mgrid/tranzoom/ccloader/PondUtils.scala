package net.mgrid.tranzoom.ccloader

import java.sql.SQLException
import com.rabbitmq.client.Channel
import java.sql.Connection
import org.springframework.integration.Message
import javax.sql.DataSource
import org.slf4j.LoggerFactory
import net.mgrid.tranzoom.error.ErrorUtils
import net.mgrid.tranzoom._
import sys.process._

trait PondUtils { self: Loader =>

  import PondUtils._

  private lazy val dataSource = newDatasource(pondHost, pondPort, pondDatabase, pondUser)

  private lazy val hostname = "hostname --fqdn".!!.filter(_ >= ' ') // filter out all control characters

  def pondReady(): Boolean = withDatabaseConnection { implicit conn =>
    singleQuery[Boolean]("SELECT pond_ready()").getOrElse(false)
  }

  def withPondSequence[T](f: String => T)(implicit channel: Channel): T =
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

  def initPond(seq: String): Unit = withDatabaseConnection { implicit conn =>
    singleQuery(s"SELECT pond_init('$seq', '$hostname')")
  }

  def resetPond(implicit channel: Channel): Unit = withDatabaseConnection { implicit conn =>
    singleQuery[String](s"SELECT pond_retseq()") map { seq =>
      logger.info(s"Return sequence $seq to broker")
      channel.basicPublish("sequencer", "pond", true /*mandatory*/ , false /*immediate*/ , null /*props*/ , seq.getBytes())
    }
  }

  def emptyPond(): Unit = withDatabaseConnection { implicit conn =>
    singleQuery("SELECT pond_empty()")
  }

  /**
   * @return Number of messages that successfully committed
   */
  def commitToPond(messages: List[Message[String]]): Int = withDatabaseConnection { implicit conn =>
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
      conn.setAutoCommit(false)
      f(conn)
    } finally {
      quietly(conn.commit())
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

}

/**
 * Helpers and database connection pooling.
 */
object PondUtils {

  import org.postgresql.ds.PGSimpleDataSource

  Class.forName("org.postgresql.Driver")

  private val logger = LoggerFactory.getLogger(PondUtils.getClass)

  def newDatasource(pondHost: String, pondPort: Int, pondDatabase: String, pondUser: String): DataSource = {
    val ds = new PGSimpleDataSource()
    ds.setServerName(pondHost)
    ds.setPortNumber(pondPort)
    ds.setDatabaseName(pondDatabase)
    ds.setUser(pondUser)

    ds
  }

}
