/**
 * Copyright (c) 2013, Portavita BV Netherlands
 */
package eu.portavita.axle.json

/**
 * Class for seamless casting of classes.
 *
 * @see http://stackoverflow.com/questions/4170949/how-to-parse-json-in-scala-using-standard-scala-classes
 */
class ClassCaster[T] {
	def unapply(a:Any):Option[T] = Some(a.asInstanceOf[T])
}