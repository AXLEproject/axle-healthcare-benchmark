package eu.portavita.axle.generatable

import java.util.concurrent.atomic.AtomicLong

object RoleId {
	private val id = new AtomicLong(0)
	def next: Long = id.incrementAndGet()
}