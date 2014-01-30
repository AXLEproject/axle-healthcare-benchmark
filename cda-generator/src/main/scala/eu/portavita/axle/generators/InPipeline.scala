package eu.portavita.axle.generators

import java.util.concurrent.atomic.AtomicBoolean

import scala.util.Random

import eu.portavita.axle.GeneratorConfig

object InPipeline {
	val config = GeneratorConfig.pipelineConfig
	val pause = new AtomicBoolean(false)

	val organizationRequests = new RequestInProgress(config.maxOrganizations)
	val patientRequests = new RequestInProgress(config.maxPatients)
	val examinationRequests = new RequestInProgress(config.maxExaminations)
	val publishRequests = new RequestInProgress(config.maxPublishRequests)

	private val random = new Random

	def waitUntilReady {
		while (pause.get()) {
			Thread.sleep(random.nextInt(250))
		}
	}

	def updatePause {
		val shouldPause = organizationRequests.paused || patientRequests.paused || examinationRequests.paused || publishRequests.paused
		System.err.println("updatePause: shouldPause = " + shouldPause.toString());
		pause.compareAndSet(!shouldPause, shouldPause)
	}
}
