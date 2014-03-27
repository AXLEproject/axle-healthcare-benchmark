package eu.portavita.axle.generators

import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

class RequestInProgress(max: Int, generators: List[RequestInProgress], val name: String) {
	private val currently = new AtomicInteger(0)
	private val overloaded = new AtomicBoolean(false)
	private val blockedBy = new AtomicInteger(0)

	def isOverloaded = overloaded.get()
	def isPaused = isOverloaded || isPausedGenerating
	def isPausedGenerating = blockedBy.get() > 0

	def mustPause(pause: Boolean) {
//		System.err.println("%s received mustPause(%s)".format(name, pause));
		if (pause) blockedBy.incrementAndGet()
		else blockedBy.decrementAndGet()
	}

	def newRequest: Int = {
		val currentNumber = currently.incrementAndGet()
		if (tooManyRequests(currentNumber)) {
			val changed = overloaded.compareAndSet(false, true)
			if (changed) {
				generators.foreach(x => x.mustPause(true))
//				System.err.println("%s: Max was %d, now %d, so pausing".format(name, max, currentNumber));
			}
		}
		currentNumber
	}

	def finishRequest: Int = {
		val currentNumber = currently.decrementAndGet()
		if (normalNumberOfRequests(currentNumber)) {
			val changed = overloaded.compareAndSet(true, false)
			if (changed) {
				generators.foreach(x => x.mustPause(false))
//				System.err.println("%s: Unpausing!".format(name));
			}
		}
		currentNumber
	}

	def current = currently.get()

	def setCurrent(to: Int) {
		currently.set(to)
	}

	private def tooManyRequests(currentNumber: Int) = currentNumber > max
	private def normalNumberOfRequests(currentNumber: Int) = currentNumber * 2 < max
}
