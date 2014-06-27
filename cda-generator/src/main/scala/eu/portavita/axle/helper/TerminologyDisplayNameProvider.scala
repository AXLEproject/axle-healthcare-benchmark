/**
 * Copyright (c) 2014, Portavita BV Netherlands
 */
package eu.portavita.axle.helper

import java.util.concurrent.ConcurrentHashMap

import eu.portavita.databus.IDisplayNameProvider
import eu.portavita.terminology.CodeSystem
import eu.portavita.terminology.LocalTerminologyCache

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
