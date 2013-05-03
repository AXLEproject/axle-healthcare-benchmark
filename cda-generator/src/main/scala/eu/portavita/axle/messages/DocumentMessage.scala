/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.messages

import org.hl7.v3.POCDMT000040ClinicalDocument

import eu.portavita.axle.generatable.Examination
import eu.portavita.axle.generatable.Patient

sealed trait DocumentMessage


/**
 * Request message to build an examination document for
 * the given examination performed on the given patient.
 */
case class ExaminationBuilderRequest (
	val patient: Patient,
	val examination: eu.portavita.concept.Examination
) extends DocumentMessage


/**
 * Result message that contains a clinical document that
 * was built.
 */
case class ExaminationBuilderResult (
	examination: POCDMT000040ClinicalDocument
) extends DocumentMessage


/**
 * Request message to marshal the given document.
 */
case class MarshalDocumentRequest (
	document: POCDMT000040ClinicalDocument
) extends DocumentMessage


/**
 * Message containing a marshalled document.
 */
case class MarshalledDocument (
	document: String
) extends DocumentMessage
