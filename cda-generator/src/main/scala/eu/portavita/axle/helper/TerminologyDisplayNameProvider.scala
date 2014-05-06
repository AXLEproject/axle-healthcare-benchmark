/**
 * Copyright (c) 2014, Portavita BV Netherlands
 */
package eu.portavita.axle.helper

import scala.collection.concurrent.TrieMap

import eu.portavita.databus.IDisplayNameProvider
import eu.portavita.terminology.LocalTerminologyCache

class TerminologyDisplayNameProvider(terminology: LocalTerminologyCache) extends IDisplayNameProvider {
	private val cache = new TrieMap[String, String]

	def get(code: String): String = {
		cache.getOrElseUpdate(code,
			terminology.getConcept(CodeSystemProvider.get(code), code).getDisplayName())
	}
}
