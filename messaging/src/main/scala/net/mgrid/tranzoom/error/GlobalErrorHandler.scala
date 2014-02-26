/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.tranzoom.error

import org.springframework.integration.MessageChannel
import org.springframework.integration.Message
import org.slf4j.LoggerFactory
import scala.beans.BeanProperty

class GlobalErrorHandler {
  import GlobalErrorHandler._

  def globalError(message: Message[Throwable]): Message[_] = {
    val ex = message.getPayload()
    logger.error(s"Fatal error, force exit so we can be restarted. ${ex.getMessage} $ex")
    System.exit(1)
    null
  }

}

object GlobalErrorHandler {
  private val logger = LoggerFactory.getLogger(GlobalErrorHandler.getClass)
}
