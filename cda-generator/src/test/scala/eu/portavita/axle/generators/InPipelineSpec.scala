package eu.portavita.axle.generators

import org.scalatest.FlatSpec
import org.scalatest.Matchers

import eu.portavita.axle.GeneratorConfig

class InPipelineSpec extends FlatSpec with Matchers {

	val maxPublishRequests = GeneratorConfig.pipelineConfig.maxPublishRequests
	val maxPatients = GeneratorConfig.pipelineConfig.maxPatients

	"InPipeline" should "instantiate correctly" in {
		InPipeline.organizationRequests.isPaused should be(false)
		InPipeline.patientRequests.isPaused should be(false)
		InPipeline.examinationRequests.isPaused should be(false)
		InPipeline.publishRequests.isPaused should be(false)
	}

	"Publishing" should "pause if the max number of requests is in the pipeline" in {
		maxOut(InPipeline.publishRequests, maxPublishRequests)
	}

	it should "continue if paused and the number of requests is low" in {
		maxOut(InPipeline.publishRequests, maxPublishRequests)

		InPipeline.publishRequests.setCurrent(maxPublishRequests / 2)
		InPipeline.publishRequests.finishRequest
		InPipeline.publishRequests.isPaused should be(false)
	}

	"max number of publish requests" should "pause patient generator" in {
		maxOut(InPipeline.publishRequests, maxPublishRequests)
		InPipeline.patientRequests.isPaused should be(true)
	}

	"publish requests" should "unpause patient generator if nr of requests is okay and patient generator was paused" in {
		maxOut(InPipeline.publishRequests, maxPublishRequests)
		InPipeline.patientRequests.isPaused should be(true)

		InPipeline.publishRequests.setCurrent(1)
		InPipeline.publishRequests.finishRequest
		InPipeline.publishRequests.isPaused should be(false)
		InPipeline.patientRequests.isPaused should be(false)
	}

	private def maxOut(requestsInProgress: RequestInProgress, max: Int) {
		requestsInProgress.setCurrent(max)
		requestsInProgress.newRequest
		requestsInProgress.isPaused should be(true)
	}

}
