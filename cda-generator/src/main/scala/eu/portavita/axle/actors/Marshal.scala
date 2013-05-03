/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.actors

import akka.actor.ActorLogging
import akka.actor.Actor
import javax.xml.bind.JAXBContext
import org.hl7.v3.POCDMT000040ClinicalDocument
import javax.xml.bind.Marshaller
import eu.portavita.axle.messages.MarshalDocumentRequest
import akka.actor.ActorRef
import java.io.StringWriter
import eu.portavita.axle.messages.MarshalledDocument
import eu.portavita.axle.Generator

/**
 * This actor receives clinical documents as POJO, marshals them, and sends the marshalled documents
 * to a writer actor.
 */
class Marshal {

	// Create JAXB context of clinical documents.
	val jaxbContext = JAXBContext.newInstance(classOf[POCDMT000040ClinicalDocument])

	// Create marshaller of clinical documents.
	val marshaller = jaxbContext.createMarshaller()
	marshaller.setProperty(Marshaller.JAXB_FORMATTED_OUTPUT, java.lang.Boolean.TRUE)


	def create (document: POCDMT000040ClinicalDocument): String = {
		val writer = new StringWriter
		// Marshal document.
		marshaller.marshal(document, writer)

		writer.toString()
	}
}
