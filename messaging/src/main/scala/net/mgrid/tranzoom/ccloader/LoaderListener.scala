/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.tranzoom.ccloader

import net.mgrid.tranzoom.rabbitmq.MessageListener

/**
 * MessageListener which converts the payload to String.
 */
class LoaderListener extends MessageListener[String] {
  override def convert(bytes: Array[Byte]): String = new String(bytes)
}