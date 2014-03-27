package eu.portavita.axle.generators

import org.junit.Test
import org.scalatest.Suite

import eu.portavita.axle.GeneratorConfig

class InPipelineSuite extends Suite {

	val maxPublishRequests = GeneratorConfig.pipelineConfig.maxPublishRequests
	val maxPatients = GeneratorConfig.pipelineConfig.maxPatients

	@Test
	def testPublishRequests {
		assert(!InPipeline.pause.get())

		maxOut(InPipeline.publishRequests, maxPublishRequests)
		assert(InPipeline.publishRequests.isPaused)
		assert(isPaused)

		InPipeline.publishRequests.setCurrent(maxPublishRequests / 2)
		InPipeline.publishRequests.finishRequest
		assert(!isPaused)
		assert(!InPipeline.publishRequests.isPaused)
	}

	@Test
	def testCombination {
		assert(!isPaused)

		maxOut(InPipeline.publishRequests, maxPublishRequests)
		maxOut(InPipeline.patientRequests, maxPatients)

		InPipeline.publishRequests.setCurrent(1)
		InPipeline.publishRequests.finishRequest
		assert(isPaused)

		InPipeline.patientRequests.setCurrent(1)
		InPipeline.patientRequests.finishRequest
		assert(!isPaused)
	}

	private def maxOut(requestsInProgress: RequestInProgress, max: Int) {
		requestsInProgress.setCurrent(max)
		requestsInProgress.newRequest
		assert(isPaused)
		assert(requestsInProgress.isPaused)
	}

	private def isPaused = InPipeline.pause.get()
}
