package eu.portavita.axle.helper

import eu.portavita.databus.messagebuilder.messagecontents.IMessageContent
import java.io.StringWriter
import javax.xml.bind.Marshaller

object MarshalHelper {

	def marshal(message: Object, marshaller: Marshaller): String = {
		val output = new StringWriter()
		marshaller.marshal(message, output)
		output.toString()
	}
}
