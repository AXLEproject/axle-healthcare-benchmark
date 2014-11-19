package eu.portavita.axle.generators

import akka.actor.ActorLogging
import akka.actor.Actor
import eu.portavita.axle.generatable.Patient
import eu.portavita.axle.generatable.Examination
import eu.portavita.axle.helper.MarshalHelper
import eu.portavita.databus.message.contents.ExaminationMessageContent
import eu.portavita.axle.publisher.PublishHelper
import eu.portavita.axle.helper.CdaValueBuilderHelper
import eu.portavita.axle.GeneratorConfig
import eu.portavita.databus.messagebuilder.builders.ExaminationBuilder
import org.hl7.v3.StrucDocText
import javax.xml.bind.Marshaller
import eu.portavita.axle.publisher.RabbitMessageQueue
import eu.portavita.databus.messagebuilder.builders.ConsentBuilder
import eu.portavita.axle.generatable.Consent
import eu.portavita.databus.message.contents.ConsentMessageContent

sealed trait ConsentMessage
case class ConsentGenerationRequest(val patient: Patient) extends ConsentMessage

class ConsentGenerator extends Actor with ActorLogging {

  private val queue = new ConsentPublisher

  /**
   * Receives and processes a message from another actor.
   */
  def receive = {
    case request @ ConsentGenerationRequest(patient) =>
      val custodian = patient.organization
      val consent = Consent.sample(patient, custodian)
      queue.publish(consent)

    case x =>
      log.warning("Received message that I cannot handle: " + x.toString)
  }

  class ConsentPublisher {
    private val publisher = new PublishHelper(context.actorSelection("/user/publisher"))

    private val consentBuilder: ConsentBuilder = {
      val (cdaValueBuilder, displayNameProvider) = CdaValueBuilderHelper.get
      new ConsentBuilder(cdaValueBuilder, displayNameProvider)
    }

    private val marshaller: Marshaller = {
      val m = GeneratorConfig.cdaJaxbContext.createMarshaller()
      m.setProperty(Marshaller.JAXB_FORMATTED_OUTPUT, true)
      m
    }

    def publish(consent: Consent) {
      val message = buildConsentMessage(consent)
      val marshalledMessage = MarshalHelper.marshal(message, marshaller)
      publisher.publish(marshalledMessage, RabbitMessageQueue.consentRoutingKey)
    }

    private def buildConsentMessage(consent: Consent): ConsentMessageContent = {
      consentBuilder.setMessageInput(consent.toConsentDTO)
      consentBuilder.build()
      consentBuilder.getMessageContent()
    }
  }

}