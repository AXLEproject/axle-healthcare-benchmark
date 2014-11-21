package eu.portavita.axle.helper

import eu.portavita.databus.data.dto.ParticipationDTO
import java.util.Date
import eu.portavita.axle.generatable.ParticipationId

object ParticipationHelper {
  
    def createParticipant(id: Long, date: Date, typeCode: String, roleId: Long): ParticipationDTO = {
      val participant = new ParticipationDTO
      participant.setId(ParticipationId.next)
      participant.setActId(id)
      participant.setFromTime(date)
      participant.setTypeCode(typeCode)
      participant.setRoleId(roleId)
      participant
    }

}