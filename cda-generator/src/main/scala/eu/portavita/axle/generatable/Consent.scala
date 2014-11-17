package eu.portavita.axle.generatable

import eu.portavita.databus.data.dto.ConsentDocumentDTO

class Consent(patient: Patient, treatmentForConsent: Treatment) {

  def toConsentDTO: ConsentDocumentDTO = {
    new ConsentDocumentDTO(null, null, null, null)
  }

}

object Consent {
  def sample(patient: Patient): Consent = {
    //    new Consent(patient)
  }
}
