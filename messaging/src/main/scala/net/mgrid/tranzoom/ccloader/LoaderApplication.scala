/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.tranzoom.ccloader

import org.springframework.context.support.ClassPathXmlApplicationContext

/**
 * Main class to start a loader node for context conduction.
 */
object LoaderApplication extends App {
  
  val configFiles = Array("/META-INF/loader/tranzoom-loader.xml")
  
  val ac = new ClassPathXmlApplicationContext(configFiles, LoaderApplication.getClass)
  
  // used for @PreDestroy annotations on Loader
  ac.registerShutdownHook()

}