/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.tranzoom.ccloader

import org.springframework.integration.support.MessageBuilder
import org.springframework.integration.Message

/**
 * Processor which returns the group messages verbatim.
 */
class AggregatorLogicProcessor {

  def aggregate(messages: java.util.List[Message[_]]): Object = messages

}
