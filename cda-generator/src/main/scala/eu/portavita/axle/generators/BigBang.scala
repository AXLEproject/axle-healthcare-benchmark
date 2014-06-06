package eu.portavita.axle.generators

import scala.concurrent.duration.DurationInt
import akka.actor.Actor
import akka.actor.ActorLogging
import akka.actor.ActorSelection.toScala
import akka.actor.Cancellable
import eu.portavita.axle.GeneratorConfig

sealed trait BigBangMessage
case class BrokerIsBlocked extends BigBangMessage
case class BrokerIsUnblocked extends BigBangMessage
case class PipelineTooFull extends BigBangMessage
case class PipelineOkay extends BigBangMessage

class BigBang extends Actor with ActorLogging {
	import context._

	val organizationGenerator = context.actorSelection("/user/organizationGenerator")

	private var scheduledRefresh: Option[Cancellable] = None
	private var nrOfRequestedCaregroups = 0

	override def preStart {
		super.preStart()
		startGenerating
	}

	private def startGenerating {
		log.info("Starting to generate.")
		scheduledRefresh = Some(system.scheduler.schedule(0.millis, 2500.millis) {
			if (GeneratorConfig.mayGenerateNewCaregroup(nrOfRequestedCaregroups)) {
				organizationGenerator ! TopLevelOrganizationRequest
				nrOfRequestedCaregroups += 1
			}
		})
	}

	private def stopGenerating {
		log.info("Stopping to generate.")
		if (scheduledRefresh.isDefined) {
			log.info("Cancelling scheduled refresh")
			scheduledRefresh.get.cancel()
		}
	}

	def receive = {
		case BrokerIsBlocked => stopGenerating
		case PipelineTooFull => stopGenerating

		case BrokerIsUnblocked => startGenerating
		case PipelineOkay => startGenerating

		case x =>
			log.warning("Received message that I cannot handle: " + x.toString)
	}

}
