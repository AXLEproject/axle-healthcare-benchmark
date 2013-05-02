package eu.portavita.axle.generatable

import java.util.Date

/**
 * Represents a healthcare worker.
 *
 * @param entityId Entity id of the worker.
 * @param name Name of the worker.
 * @param birthDate Birth date of the worker.
 */
class Employee(
	entityId: Int,
	name: PersonName,
	birthDate: Date) extends Person(entityId, name, birthDate) {
}
