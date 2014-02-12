/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.tranzoom.ingress.xml

import javax.xml.parsers.DocumentBuilderFactory
import javax.xml.transform.dom.DOMSource
import java.io.ByteArrayInputStream
import org.xml.sax.InputSource
import java.io.ByteArrayOutputStream
import javax.xml.transform.stream.StreamResult
import javax.xml.transform.dom.DOMResult
import javax.xml.transform.TransformerFactory
import org.springframework.integration.xml.transformer.ResultTransformer
import javax.xml.transform.Result

/**
 * Convert to and from XML compatible types.
 */
object XmlConverter {

  private val documentFactory = {
    val factory = DocumentBuilderFactory.newInstance()
    factory.setNamespaceAware(true)
    factory.setIgnoringElementContentWhitespace(true)
    factory.setIgnoringComments(true)
    factory
  }

  private val transformFactory = TransformerFactory.newInstance()

  def toDOMSource(bytes: Array[Byte]): DOMSource = {
    val is = new ByteArrayInputStream(bytes)
    val src = new InputSource(is)
    src.setEncoding("UTF-8")
    val doc = documentFactory.newDocumentBuilder().parse(is)
    new DOMSource(doc, src.getSystemId)
  }

  def toBytes(source: DOMSource): Array[Byte] = {
    val result = new ByteResult
    val transformer = transformFactory.newTransformer
    transformer.transform(source, result)
    result.toByteArray
  }

}

class ByteResult extends StreamResult(new ByteArrayOutputStream) {
  def toByteArray: Array[Byte] = getOutputStream match {
    case bs: ByteArrayOutputStream => bs.toByteArray()
  }
}

class ResultToSourceTransformer extends ResultTransformer {
  override def transformResult(result: Result): Object = result match {
    case dr: DOMResult => new DOMSource(dr.getNode())
    case _ => throw new UnsupportedOperationException("Result type not supported")
  }
}