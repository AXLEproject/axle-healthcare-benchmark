/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
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
import net.mgrid.tranzoom.error.ErrorHandler
import com.rabbitmq.client.AMQP.BasicProperties
import net.mgrid.messaging.testutils.DatabaseUtils

/**
 * Requires RIM database server on localhost, used for test pond and lake.
 */
class LoaderIntegrationSpec extends FlatSpec with Matchers {
  
  import LoaderIntegrationSpec._
  
  makePond(pondName)
  makeLake(lakeName)
  
  "Loader" should "initialze pond on start" in {
    val loader = initLoader
    val range = "1:1000"
    val envelope = new Envelope(1, false, "sequencer", "seq")
    val response = new GetResponse(envelope, null, range.getBytes(), 1)
    val (connFactory, channel) = rabbitMock
    
    when(channel.basicGet("pond-seq", false)).thenReturn(response)
    
    loader.rabbitFactory = connFactory
    
    isPondReady should be (false)
    loader.start
    isPondReady should be (true)
    
  }
  
  it should "upload message group to the lake" in {
    import scala.collection.JavaConverters._
    
    val loader = initLoader
    val confirmListener = mock(classOf[PublishConfirmListener])
    val sql = Source.fromFile("test-data/fhir_0001_prac.sql").mkString
    val msg  = MessageBuilder.withPayload(sql).build()
    val group = MessageBuilder.withPayload(seqAsJavaListConverter(Seq(msg)).asJava).build()
    
    loader.confirmListener = confirmListener
    
    isPondReady should be (true)
    
    // no person should be in the pond and lake before load
    hasPerson(pondJdbc(pondName)) should be (false)
    hasPerson(lakeJdbc(lakeName)) should be (false)

    loader.loadGroup(group)
    
    // no person should be in the pond but does in the lake after load
    hasPerson(pondJdbc(pondName)) should be (false)
    hasPerson(lakeJdbc(lakeName)) should be (true)
    
    val outArgument = ArgumentCaptor.forClass(classOf[Message[String]])
    verify(confirmListener).deliverConfirm(outArgument.capture())
    val confirm = outArgument.getValue()
    confirm should be (msg)
  }
  
  it should "send message to errorHandler on upload fail" in {
    import scala.collection.JavaConverters._
    
    val loader = initLoader
    val confirmListener = mock(classOf[PublishConfirmListener])
    val errorHandler = mock(classOf[ErrorHandler])
    val sql = Source.fromFile("test-data/fhir_0001_prac.sql").mkString
    val msg  = MessageBuilder.withPayload(sql).build()
    val group = MessageBuilder.withPayload(seqAsJavaListConverter(Seq(msg)).asJava).build()
    
    loader.pondUploadScript = "doesnotexist"
    loader.confirmListener = confirmListener
    loader.errorHandler = errorHandler
    
    isPondReady should be (true)
    
    // no person should be in the pond before load
    hasPerson(pondJdbc(pondName)) should be (false)

    loader.loadGroup(group)
    
    // no person should be in the pond after a failed load
    hasPerson(pondJdbc(pondName)) should be (false)
    
    // message should be passed to the error handler
    val outArgument = ArgumentCaptor.forClass(classOf[Message[String]])
    verify(errorHandler).error(outArgument.capture(), anyString(), anyString())
    val errMessage = outArgument.getValue()
    errMessage should be (msg)
    
    verify(confirmListener, never()).deliverConfirm(anyObject())
  }
  
  // this test should come at the end as it assumes a ready pond and stops it
  it should "return sequence on stop" in {
    val loader = initLoader
    val (connFactory, channel) = rabbitMock
    
    loader.rabbitFactory = connFactory
    
    isPondReady should be (true)
    
    loader.stop
    
    val outArgument = ArgumentCaptor.forClass(classOf[Array[Byte]])
    verify(channel).basicPublish(
        anyString(), 
        anyString(), 
        anyBoolean(), 
        anyBoolean(), 
        anyObject(), 
        outArgument.capture())
    val range = new String(outArgument.getValue())
    
    range should fullyMatch regex """\d+:\d+"""
    
    isPondReady should be (false)
  }
}

private object LoaderIntegrationSpec extends DatabaseUtils {
  
  val pondName = "pondtest"
  val lakeName = "laketest"
  
  def initLoader = {
    val loader = new Loader()
    loader.setPondUploadScript("../pond/pond_upload.sh")
    loader.setPondDatabase(pondName)
    loader.setPondUser(user)
    loader.setLakeDatabase(lakeName)
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
  
  def isPondReady: Boolean = withDatabaseConnection(pondJdbc(pondName)) { conn =>
    query[Boolean](conn, "SELECT pond_ready()") match {
      case Some(isReady) if isReady => true
      case _ => false
    }
  }
  
}