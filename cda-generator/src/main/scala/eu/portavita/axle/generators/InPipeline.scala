package eu.portavita.axle.generators

import java.util.concurrent.atomic.AtomicBoolean

import scala.util.Random

import eu.portavita.axle.GeneratorConfig

object InPipeline {
	val config = GeneratorConfig.pipelineConfig
	val pause = new AtomicBoolean(false)

	val organizationRequests = new RequestInProgress(config.maxOrganizations, Nil, "organizations")
	val patientRequests = new RequestInProgress(config.maxPatients, List(organizationRequests), "patients")
	val examinationRequests = new RequestInProgress(config.maxExaminations, List(patientRequests), "examinations")
	val publishRequests = new RequestInProgress(config.maxPublishRequests, List(examinationRequests, patientRequests, organizationRequests), "publish requests")

	private val random = new Random

	def waitGeneratingOrganizations = waitUntilReady(organizationRequests)
	def waitGeneratingPatients = waitUntilReady(patientRequests)
	def waitGeneratingExaminations = waitUntilReady(examinationRequests)

	private def waitUntilReady(rip: RequestInProgress) {
		while (rip.isPausedGenerating) {
			Thread.sleep(random.nextInt(500))
		}
	}

}
