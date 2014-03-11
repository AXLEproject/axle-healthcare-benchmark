package net.mgrid.tranzoom.rabbitmq

import com.rabbitmq.client.Channel
import org.springframework.beans.factory.annotation.Required
import javax.annotation.Resource
import net.mgrid.tranzoom._
import org.springframework.amqp.rabbit.connection.ConnectionFactory

trait RabbitResourceProvider {
  def rabbitConnectionFactory: ConnectionFactory
}

trait RabbitUtils { self: RabbitResourceProvider =>
  
  def withRabbitChannel[A](f: Channel => A): A = {
    val conn = rabbitConnectionFactory.createConnection()
    val channel = conn.createChannel(false)
    try {
      f(channel)
    } finally {
      quietly(channel.close())
      quietly(conn.close())
    }
  }

}