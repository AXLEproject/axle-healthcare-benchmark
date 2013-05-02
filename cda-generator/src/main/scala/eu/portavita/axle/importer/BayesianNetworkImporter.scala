package eu.portavita.axle.importer

import scala.io.BufferedSource
import scala.util.parsing.json.JSON
import scala.collection.mutable
import eu.portavita.axle.json.AsMap
import eu.portavita.axle.json.AsList

class BayesianNetworkImporter {

	def readJson (source: BufferedSource) = {
		val sourceString = source.mkString

		val freq = new mutable.ArrayBuffer[mutable.Map[String, String]]

		for (
			Some(AsMap(map)) <- List(JSON.parseFull(sourceString));
			(key,value) <- map;
			AsList(list) = map(key)
		) {
			key match {
				case "Freq" => println("Frequencies...")
				case x =>
					list.foreach(e => println(e))
			}
		}

	}
}