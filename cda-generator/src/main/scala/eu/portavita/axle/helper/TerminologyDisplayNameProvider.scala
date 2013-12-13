/**
 * Copyright (c) 2014, Portavita BV Netherlands
 */
package eu.portavita.axle.helper

import eu.portavita.databus.messagebuilder.cda.IDisplayNameProvider
import eu.portavita.terminology.LocalTerminologyCache
import eu.portavita.databus.messagebuilder.cda.ValueType
import eu.portavita.terminology.CodeSystem
import java.util.concurrent.ConcurrentHashMap

class TerminologyDisplayNameProvider(terminology: LocalTerminologyCache) extends IDisplayNameProvider {

	val cache = new ConcurrentHashMap[String, String]

	def get(code: String): String = {
		if (!cache.containsKey(code)) {
			val codeSystem = CodeSystem.guess(code)
			val concept = terminology.getConcept(codeSystem, code)
			cache.put(code, concept.getDisplayName())
		}
		cache.get(code)
	}

}
