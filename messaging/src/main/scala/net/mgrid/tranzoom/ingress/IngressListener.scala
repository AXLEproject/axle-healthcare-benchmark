/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.tranzoom.ingress

import net.mgrid.tranzoom.ingress.xml.XmlConverter
import javax.xml.transform.dom.DOMSource
import net.mgrid.tranzoom.rabbitmq.MessageListener

/**
 * MessageListener which converts message payloads to DOMSource.
 */
class IngressListener extends MessageListener[DOMSource] {
  override def convert(bytes: Array[Byte]): DOMSource = XmlConverter.toDOMSource(bytes)
}
