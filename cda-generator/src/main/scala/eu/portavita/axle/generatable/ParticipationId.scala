package eu.portavita.axle.generatable

import java.util.concurrent.atomic.AtomicInteger

object ParticipationId {
  private val id = new AtomicInteger(0)
  def next: Int = id.incrementAndGet()
}