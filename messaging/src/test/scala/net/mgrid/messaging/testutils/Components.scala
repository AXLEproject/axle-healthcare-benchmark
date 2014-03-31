/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.messaging.testutils

import java.sql.DriverManager
import com.rabbitmq.client.Channel
import com.rabbitmq.client.ConnectionFactory
import com.rabbitmq.client.MessageProperties
import scala.concurrent.ExecutionContext
import scala.concurrent.Future

trait DatabaseUtils {

  import sys.process._

  Class.forName("org.postgresql.Driver")

  val user = System.getProperty("user.name")
  
  def pondJdbc(name: String = "pondtest") = s"jdbc:postgresql://localhost:5432/$name?user=$user"
  def lakeJdbc(name: String = "laketest") = s"jdbc:postgresql://localhost:5432/$name?user=$user"

  def makePond(name: String = "pondtest") = s"./test-tools/makepond.sh $name".!!
  def makeLake(name: String = "laketest") = s"./test-tools/makelake.sh $name".!!

  def hasPerson(jdbcUri: String): Boolean = withDatabaseConnection(jdbcUri) { conn =>
    query[String](conn, "SELECT \"name\" FROM \"Person\"").nonEmpty
  }

  def documentCount(jdbcUri: String): Long = withDatabaseConnection(jdbcUri) { conn =>
    query[Long](conn, "SELECT count(*) FROM \"Document\"").get
  }

  def withDatabaseConnection[A](jdbcUri: String)(f: java.sql.Connection => A): A = {
    val conn = DriverManager.getConnection(jdbcUri)
    try {
      f(conn)
    } finally {
      conn.close()
    }
  }

  def query[T](conn: java.sql.Connection, sql: String): Option[T] = {
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

}

trait RabbitUtils {
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

  def publish(exchange: String, routingKey: String, payload: String) =
    withChannel(_.basicPublish(exchange, routingKey, MessageProperties.TEXT_PLAIN, payload.getBytes()))

  def queueSize(queue: String): Int =
    withChannel(_.queueDeclarePassive(queue).getMessageCount())
    
  def queuePurge(queue: String): Unit = withChannel (_.queuePurge(queue))

  def consumers(queue: String): Boolean =
    withChannel (_.queueDeclarePassive(queue).getConsumerCount > 0)

  def withChannel[A](f: Channel => A): A = {
    val channel = conn.createChannel()
    try {
      f(channel)
    } finally {
      channel.close()
    }
  }
}