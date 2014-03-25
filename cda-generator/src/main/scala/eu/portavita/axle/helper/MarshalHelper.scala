package eu.portavita.axle.helper

import java.io.StringWriter

import eu.portavita.databus.message.contents.IMessageContent
import javax.xml.bind.Marshaller

object MarshalHelper {

	def marshal(message: IMessageContent, marshaller: Marshaller): String = {
		val output = new StringWriter()
		marshaller.marshal(message, output)
		output.toString()
	}
}
