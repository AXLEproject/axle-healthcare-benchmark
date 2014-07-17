package eu.portavita.axle.generators

import org.scalatest.Matchers
import org.scalatest.FlatSpec

class RequestInProgressSpec extends FlatSpec with Matchers {
	val max = 4564
	val name = "the name"

	"RequestInProgress" should "be instantiated correctly" in {
		val rip = new RequestInProgress(max, List.empty, name)
		rip.current should be(0)
		rip.isOverloaded should be(false)
		rip.isPaused should be(false)
		rip.isPausedGenerating should be(false)
	}

	"setCurrent" should "set the number of current requests correctly" in {
		val number = 654
		val rip = new RequestInProgress(max, List.empty, name)
		rip.setCurrent(number)
		rip.current should be(number)
	}

	"newRequest" should "add a current request if newRequest is called" in {
		val rip = new RequestInProgress(max, List.empty, name)
		rip.newRequest
		rip.current should be(1)
	}

	it should "pause when the maximum number of requests is reached" in {
		val rip = new RequestInProgress(max, List.empty, name)
		rip.setCurrent(max)
		rip.isPaused should be(false)

		rip.newRequest
		rip.isPaused should be(true)
	}

	"finishRequest" should "subtract a current request if finishRequest is called" in {
		val rip = new RequestInProgress(max, List.empty, name)
		rip.newRequest
		rip.finishRequest
		rip.current should be(0)
	}

	it should "continue when paused and less than half of max current requests" in {
		val max = 2
		val rip = new RequestInProgress(max, List.empty, name)
		rip.newRequest should be(1)
		rip.isPaused should be(false)
		rip.newRequest should be(2)
		rip.isPaused should be(false)
		rip.newRequest should be(3)
		rip.isPaused should be(true)

		rip.finishRequest should be(2)
		rip.isPaused should be(true)
		rip.finishRequest should be(1)
		rip.isPaused should be(true)
		rip.finishRequest should be(0)
		rip.isPaused should be(false)
	}

	"mustPause" should "pause if it is blocked by another" in {
		val rip = new RequestInProgress(max, List.empty, name)
		rip.mustPause(true)
		rip.isPaused should be(true)
	}

	it should "contiue if it was blocked by another but not anymore" in {
		val rip = new RequestInProgress(max, List.empty, name)
		rip.mustPause(true)
		rip.isPaused should be(true)
		rip.mustPause(false)
		rip.isPaused should be(false)
	}
}