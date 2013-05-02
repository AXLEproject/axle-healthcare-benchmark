package eu.portavita.axle.messages

sealed trait IdMessage

case class IdRequest(n: Int)

case class IdResult (id: Int)