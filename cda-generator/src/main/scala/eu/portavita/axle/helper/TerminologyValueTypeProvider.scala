/**
 * Copyright (c) 2014, Portavita BV Netherlands
 */
package eu.portavita.axle.helper

import scala.collection.concurrent.TrieMap

import eu.portavita.databus.messagebuilder.cda.IValueTypeProvider
import eu.portavita.databus.messagebuilder.cda.ValueType
import eu.portavita.terminology.LocalTerminologyCache

class TerminologyValueTypeProvider(terminology: LocalTerminologyCache) extends IValueTypeProvider {
	private val cache = new TrieMap[String, ValueType]

	override def get(code: String): ValueType = {
		cache.getOrElseUpdate(code, getValueTypeOf(code))
	}

	private def getValueTypeOf(code: String) = {
    val x = terminology.getConcept(CodeSystemProvider.get(code), code).getValueType()
    if (x == null) {
      System.err.println(code)
      System.err.println(CodeSystemProvider.get(code))
      System.err.println(terminology.getConcept(CodeSystemProvider.get(code), code))
    }
		ValueType.valueOf(x)
  }

}
