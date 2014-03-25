/**
 * Copyright (c) 2014, Portavita BV Netherlands
 */
package eu.portavita.axle.helper

import java.util.concurrent.ConcurrentHashMap

import eu.portavita.databus.messagebuilder.cda.IValueTypeProvider
import eu.portavita.databus.messagebuilder.cda.ValueType
import eu.portavita.terminology.CodeSystem
import eu.portavita.terminology.LocalTerminologyCache

class TerminologyValueTypeProvider(terminology: LocalTerminologyCache) extends IValueTypeProvider {

	val cache = new ConcurrentHashMap[String, ValueType]

	override def get(code: String): ValueType = {
		if (!cache.containsKey(code)) {
			val codeSystem = CodeSystem.guess(code)
			val concept = terminology.getConcept(codeSystem, code)
			cache.put(code, ValueType.valueOf(concept.getValueType()))
		}
		cache.get(code)
	}

}
