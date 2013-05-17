/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.helper
import javax.xml.bind.JAXBContext
import org.hl7.v3.POCDMT000040ClinicalDocument
import javax.xml.bind.Marshaller
import java.io.StringWriter
import org.hl7.v3.POCDMT000040ClinicalDocument

/**
 * This actor receives clinical documents as POJO, marshals them, and sends the marshalled documents
 * to a writer actor.
 */
class Marshal {

	// Create JAXB context of clinical documents.
	private val jaxbContext = JAXBContext.newInstance(classOf[POCDMT000040ClinicalDocument])

	// Create marshaller of clinical documents.
	private val marshaller = jaxbContext.createMarshaller()
	marshaller.setProperty(Marshaller.JAXB_FORMATTED_OUTPUT, java.lang.Boolean.TRUE)

	/**
	 * Returns marshalled version of given document.
	 *
	 * @return String with marshalled XML of given document
	 */
	def create (document: POCDMT000040ClinicalDocument): String = {
		val writer = new StringWriter
		// Marshal document.
		marshaller.marshal(document, writer)

		writer.toString()
	}
}
