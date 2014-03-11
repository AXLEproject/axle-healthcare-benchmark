package net.mgrid

import org.slf4j.LoggerFactory
package object tranzoom {
  
  private val logger = LoggerFactory.getLogger("tranzoom")
  
  def quietly[T](f: => T): Unit = {
    try {
      f
    } catch {
      case ex: Throwable => /* ssst */ logger.info(s"Quietly ignoring exception ${ex.getMessage}")
    }
  }

}