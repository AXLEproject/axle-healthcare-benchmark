/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.messaging.publish

import scala.io.Source
import scala.sys.process._

import com.rabbitmq.client.ConnectionFactory
import com.rabbitmq.client.MessageProperties

object PublishDir extends App {

  type Options = Map[Symbol, String]

  val usage = """
    Usage: PublishDir [OPTIONS]

    OPTIONS:
      -h                 Display this help message and exit
      -u USERNAME        Set RabbitMQ user to USERNAME (default: guest)
      -p PASSWORD        Set RabbitMQ password to PASSWORD (default: guest)
      -v VHOST           Set RabbitMQ vhost to VHOST (default: /)
      -n HOSTNAME        Set RabbitMQ hostname to HOSTNAME (default: localhost)
      -e EXCHANGE        Set RabbitMQ exchange to EXCHANGE (default: amqp.topic)
      -r KEY             Set RabbitMQ routing key to KEY (default: key)
      -d DIR             Set directory to read filed from to DIR (default .)
      -l                 Should publish loop forever
  """

  def parseOption(map: Options, opts: List[String]): Options = {
    opts match {
      case Nil => map
      case "-h" :: tail => println(usage); System.exit(0); map
      case "-u" :: username :: tail => parseOption(map + ('username -> username), tail)
      case "-p" :: password :: tail => parseOption(map + ('password -> password), tail)
      case "-v" :: vhost :: tail => parseOption(map + ('vhost -> vhost), tail)
      case "-n" :: hostname :: tail => parseOption(map + ('hostname -> hostname), tail)
      case "-e" :: exchange :: tail => parseOption(map + ('exchange -> exchange), tail)
      case "-r" :: key :: tail => parseOption(map + ('key -> key), tail)
      case "-d" :: dir :: tail => parseOption(map + ('dir -> dir), tail)
      case "-l" :: tail => parseOption(map + ('loop -> "true"), tail)
      case o @ _ => throw new Exception(s"Invalid argument: $o")
    }
  }

  def start() = {
    val opt = parseOption(Map(), args.toList)

    println(s"Running with options $opt")

    val factory = new ConnectionFactory
    factory.setUsername(opt.getOrElse('username, "guest"))
    factory.setPassword(opt.getOrElse('password, "guest"))
    factory.setVirtualHost(opt.getOrElse('vhost, "/"))
    factory.setHost(opt.getOrElse('hostname, "localhost"))
    factory.setPort(5672)
    val conn = factory.newConnection()
    val channel = conn.createChannel()
    val exchangeName = opt.getOrElse('exchange, "amqp.topic")
    val routingKey = opt.getOrElse('key, "key")
    val loop = opt.contains('loop)

    def publish(filename: String): Unit = {
      val source = Source.fromFile(filename)(scala.io.Codec.UTF8)
      val byteArray = source.map(_.toByte).toArray
      channel.basicPublish(exchangeName, routingKey, MessageProperties.PERSISTENT_TEXT_PLAIN, byteArray)
      source.close()
    }

    val files = stringToProcess(s"find ${opt.getOrElse('dir, ".")} -type f").lines.toList

    import scala.annotation.tailrec
    @tailrec def run(): Unit = {
      files foreach publish
      if (loop) run()
    }

    run()

    channel.close()
    conn.close()
  }

  start()

}
