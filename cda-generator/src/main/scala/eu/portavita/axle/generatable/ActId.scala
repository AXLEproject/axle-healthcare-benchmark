package eu.portavita.axle.generatable

import scala.actors.threadpool.AtomicInteger

object ActId {
	private val id = new AtomicInteger(0)
	def next: Int = id.incrementAndGet()
}
