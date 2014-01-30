package eu.portavita.axle.generators

import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

class RequestInProgress(max: Int) {
	private val currently = new AtomicInteger(0)
	private val tooMuch = new AtomicBoolean(false)

	def paused = tooMuch.get()

	def newRequest: Int = {
		val currentNumber = currently.incrementAndGet()
		if (currentNumber > max) {
			val changed = tooMuch.compareAndSet(false, true)
			if (changed) InPipeline.pause.set(true)
		}
		currentNumber
	}

	def finishRequest: Int = {
		val currentNumber = currently.decrementAndGet()
		if (currentNumber * 2 < max) {
			val changed = tooMuch.compareAndSet(true, false)
			if (changed) InPipeline.updatePause
		}
		currentNumber
	}

	def current = currently.get()

	def setCurrent(to: Int) {
		currently.set(to)
	}
}
