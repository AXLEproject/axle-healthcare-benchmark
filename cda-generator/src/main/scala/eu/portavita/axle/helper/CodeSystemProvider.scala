package eu.portavita.axle.helper

import scala.collection.concurrent.TrieMap

import eu.portavita.terminology.CodeSystem

object CodeSystemProvider {
	private val cache = new TrieMap[String, CodeSystem]

	def get(code: String): CodeSystem = {
		cache.getOrElseUpdate(code, CodeSystem.guess(code))
	}
}
