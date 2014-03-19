/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.tranzoom.ingress

import org.springframework.context.support.ClassPathXmlApplicationContext

/**
 * Main class to start an ingress node.
 */
object IngressApplication extends App {
  
  val configFiles = Array("/META-INF/ingress/tranzoom-ingress.xml")
  
  val ac = new ClassPathXmlApplicationContext(configFiles, IngressApplication.getClass)
  
}