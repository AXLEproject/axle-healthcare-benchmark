/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.helper

import org.hl7.v3.POCDMT000040ClinicalDocument
import eu.portavita.axle.generatable.Patient
import eu.portavita.axle.generators.ExaminationDataProvider
import eu.portavita.concept.Examination
import eu.portavita.axle.Generator

/**
 * This actor receives requests to build clinical documents for examinations, and sends those clinical
 * documents to a marshal actor.
 */
class ExaminationDocumentBuilder {

	// Create data provider.
	val provider = new ExaminationDataProvider

	// Create document builder.
	val builder = new eu.portavita.builder.ExaminationDocumentBuilder(Generator.terminology, provider)

	def create (patient: Patient, examination: Examination): POCDMT000040ClinicalDocument = {
		val id = provider.add(patient, examination)
		builder.create(id)
	}
}
