/**
 * Copyright (c) 2014, Portavita BV Netherlands
 */
package eu.portavita.axle.helper

import eu.portavita.databus.messagebuilder.cda.CdaValueBuilder
import eu.portavita.axle.GeneratorConfig
import eu.portavita.databus.messagebuilder.cda.UcumTransformer

object CdaValueBuilderHelper {

	def get: (CdaValueBuilder, TerminologyDisplayNameProvider) = {
		val cdaValueBuilder = new CdaValueBuilder()
		val valueTypeProvider = new TerminologyValueTypeProvider(GeneratorConfig.terminology)
		val displayNameProvider = getDisplayNameProvider
		val ucumTransformer = new UcumTransformer()
		cdaValueBuilder.setValueTypeProvider(valueTypeProvider)
		cdaValueBuilder.setUcum(ucumTransformer)
		cdaValueBuilder.setDisplayNameProvider(displayNameProvider)
		(cdaValueBuilder, displayNameProvider)
	}

	def getDisplayNameProvider: TerminologyDisplayNameProvider = {
		new TerminologyDisplayNameProvider(GeneratorConfig.terminology)
	}

}
