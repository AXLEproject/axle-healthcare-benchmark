/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.messaging.error

import org.scalatest.FlatSpec
import org.scalatest.Matchers
import com.rabbitmq.client.Channel
import net.mgrid.tranzoom.TranzoomHeaders
import net.mgrid.tranzoom.error.ErrorUtils
import org.springframework.integration.xml.selector.XmlValidatingMessageSelector
import org.springframework.core.io.DefaultResourceLoader

class ErrorUtilsSpec extends FlatSpec with Matchers {
  
  import org.mockito.Mockito._
  
  val resourceLoader = new DefaultResourceLoader

  "Error messages" should "adhere to the xml schema" in {
    val errorType = "sometype"
    val reason = "some reason"
    val source = ("TEST".getBytes(), 1L, mock(classOf[Channel]))
    val validator = new XmlValidatingMessageSelector(resourceLoader.getResource("error-xsd/error.xsd"), "http://www.w3.org/2001/XMLSchema")
    validator.setThrowExceptionOnRejection(true)

    val result = ErrorUtils.errorMessage(errorType, reason, source)

    validator.accept(result) should be (true)
  }

  it should "add the source reference as header" in {
    val errorType = "sometype"
    val reason = "some reason"
    val source = ("TEST".getBytes(), 1L, mock(classOf[Channel]))

    val result = ErrorUtils.errorMessage(errorType, reason, source)

    result.getHeaders.get(TranzoomHeaders.HEADER_SOURCE_REF) should be (source)
  }
}
