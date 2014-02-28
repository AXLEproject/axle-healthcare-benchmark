/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.tranzoom.error

/**
 * Utilities for creating formatted error messages.
 */
object ErrorUtils {

  // error types should only use [a-zA-Z0-9] for use in amqp routing keys
  val ERROR_TYPE_INTERNAL = "internal"
  val ERROR_TYPE_VALIDATION = "validation"
    
}
