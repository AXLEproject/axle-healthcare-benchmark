/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.tranzoom.error

import org.springframework.integration.Message
import scala.xml.PCData
import org.springframework.integration.support.MessageBuilder
import scala.xml.XML
import java.io.StringWriter
import org.springframework.integration.amqp.AmqpHeaders
import net.mgrid.tranzoom.rabbitmq.MessageListener

/**
 * Utilities for creating formatted error messages.
 */
object ErrorUtils {

  import MessageListener.SourceRef
  import net.mgrid.tranzoom.TranzoomHeaders._

  // error types should only use [a-zA-Z0-9] for use in amqp routing keys
  val ERROR_TYPE_INTERNAL = "internal"
  val ERROR_TYPE_VALIDATION = "validation"

  def errorMessage(errorType: String, reason: String, ref: SourceRef): Message[_] = {
    val (payload, _, _) = ref
    val sourcePayload = new String(payload)

    val xmlPayload =
      <error xmlns="urn:mgrid-net:tranzoom">
        <type>{ errorType }</type>
        <reason>{ PCData(reason) }</reason>
        <source>{ PCData(sourcePayload) }</source>
      </error>

    // we need this to include the xml declaration
    val payloadWriter = new StringWriter
    XML.write(payloadWriter, xmlPayload, "UTF-8", true, null)

    MessageBuilder.withPayload(payloadWriter.toString)
      .setHeader(HEADER_SOURCE_REF, ref)
      .build()
  }

}
