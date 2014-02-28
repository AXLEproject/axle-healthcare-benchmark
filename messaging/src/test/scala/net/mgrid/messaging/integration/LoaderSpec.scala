package net.mgrid.messaging.integration

import org.scalatest.Matchers
import org.scalatest.FlatSpec
import net.mgrid.tranzoom.ccloader.Loader
import org.mockito.Mockito._
import org.mockito.Matchers._
import org.springframework.amqp.rabbit.connection.ConnectionFactory
import org.springframework.amqp.rabbit.connection.Connection
import com.rabbitmq.client.Channel
import com.rabbitmq.client.GetResponse
import com.rabbitmq.client.Envelope
import org.mockito.ArgumentCaptor
import org.springframework.integration.support.MessageBuilder
import net.mgrid.tranzoom.rabbitmq.PublishConfirmListener
import org.springframework.integration.Message
import scala.io.Source
import java.sql.DriverManager
import javax.annotation.PostConstruct
import javax.annotation.PreDestroy
import net.mgrid.tranzoom.rabbitmq.PublishConfirmListener
import org.springframework.amqp.rabbit.connection.Connection
import scala.collection.JavaConverters.seqAsJavaListConverter
import scala.sys.process.stringToProcess

/**
 * Requires RIM database server on localhost, used for test pond and lake.
 */
class LoaderSpec extends FlatSpec with Matchers {
  
  import LoaderSpec._
  
  makePond
  makeLake
  
  "Loader" should "initialze pond on start" in {
    val loader = initLoader
    val range = "1:1000"
    val envelope = new Envelope(1, false, "sequencer", "seq")
    val response = new GetResponse(envelope, null, range.getBytes(), 1)
    val (connFactory, channel) = rabbitMock
    
    when(channel.basicGet("pond-seq", false)).thenReturn(response)
    
    loader.rabbitConnectionFactory = connFactory
    
    isPondReady(loader) should be (false)
    loader.start
    isPondReady(loader) should be (true)
    
  }
  
  it should "upload message group to the lake" in {
    import scala.collection.JavaConverters._
    
    val loader = initLoader
    val confirmListener = mock(classOf[PublishConfirmListener])
    val sql = Source.fromFile("test-data/fhir_0001_prac.sql").mkString
    val msg  = MessageBuilder.withPayload(sql).build()
    val group = MessageBuilder.withPayload(seqAsJavaListConverter(Seq(msg)).asJava).build()
    
    loader.confirmListener = confirmListener
    
    isPondReady(loader) should be (true)
    
    // no person should be in the pond and lake before load
    hasPerson(loader, pondJdbc) should be (false)
    hasPerson(loader, lakeJdbc) should be (false)

    loader.loadGroup(group)
    
    // no person should be in the pond but does in the lake after load
    hasPerson(loader, pondJdbc) should be (false)
    hasPerson(loader, lakeJdbc) should be (true)
    
    val outArgument = ArgumentCaptor.forClass(classOf[Message[String]])
    verify(confirmListener).deliverConfirm(outArgument.capture())
    val confirm = outArgument.getValue()
    confirm should be (msg)
  }
  
  // this test should come at the end as it assumes a ready pond
  it should "return sequence on stop" in {
    val loader = initLoader
    val (connFactory, channel) = rabbitMock
    
    loader.rabbitConnectionFactory = connFactory
    
    isPondReady(loader) should be (true)
    
    loader.stop
    
    val outArgument = ArgumentCaptor.forClass(classOf[Array[Byte]])
    //verify(channel).basicPublish("sequencer", "pond", true, false, null, outArgument.capture())
    //val range = new String(outArgument.getValue())
    
    isPondReady(loader) should be (false)
  }
}

private object LoaderSpec {
  import sys.process._
  
  Class.forName("org.postgresql.Driver")
  
  val user = System.getProperty("user.name")
  val pondJdbc = s"jdbc:postgresql://localhost:5432/pondtest?user=$user"
  val lakeJdbc = s"jdbc:postgresql://localhost:5432/laketest?user=$user"
  
  def makePond = "./test-tools/makepond.sh pondtest".!!
  def makeLake = "./test-tools/makelake.sh laketest".!!
  
  def initLoader = {
    val loader = new Loader()
    val user = System.getProperty("user.name")
    loader.setPondDatabase("pondtest")
    loader.setPondUser(user)
    loader.setLakeDatabase("laketest")
    loader.setLakeUser(user)
    loader
  }
  
  def rabbitMock: (ConnectionFactory, Channel) = {
    val cf = mock(classOf[ConnectionFactory])
    val conn = mock(classOf[Connection])
    val chan = mock(classOf[Channel])
    
    when(conn.createChannel(anyBoolean())).thenReturn(chan)
    when(cf.createConnection()).thenReturn(conn)
    
    (cf, chan)
  }
  
  def isPondReady(loader: Loader): Boolean = withDatabaseConnection(pondJdbc) { conn =>
    query[Boolean](conn, "SELECT pond_ready()") match {
      case Some(isReady) if isReady => true
      case _ => false
    }
  }
  
  def hasPerson(loader: Loader, jdbcUri: String): Boolean = withDatabaseConnection(jdbcUri) { conn =>
    query[String](conn, "SELECT \"name\" FROM \"Person\"").nonEmpty
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