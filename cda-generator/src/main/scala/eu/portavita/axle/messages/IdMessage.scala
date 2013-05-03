/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.messages

sealed trait IdMessage

case class IdRequest(n: Int)

case class IdResult (id: Int)