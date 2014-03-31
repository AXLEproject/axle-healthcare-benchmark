/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package net.mgrid.messaging.integration

import org.scalatest.Matchers
import org.scalatest.FlatSpec
import org.scalatest.BeforeAndAfter
import net.mgrid.messaging.testutils.DatabaseUtils
import net.mgrid.messaging.testutils.RabbitUtils
import scala.concurrent._
import scala.concurrent.duration._
import scala.collection.mutable
import scala.concurrent.ExecutionContext.Implicits.global
import scala.language.postfixOps
import scala.sys.process.Process
import scala.sys.process.stringSeqToProcess
import scala.sys.process.stringToProcess
import scala.util.Try
import org.slf4j.LoggerFactory

class TranzoomIntegrationSpec extends FlatSpec with Matchers with BeforeAndAfter with DatabaseUtils with RabbitUtils {

  import TranzoomIntegrationSpec._
  import scala.collection.mutable
  import sys.process._
  import scala.concurrent.ExecutionContext.Implicits.global
  
  initBroker
  makePond(pondName)
  makeLake(lakeName)

  val processMap = mutable.Map[Symbol, Process]()

  before {
    withChannel { channel =>
      // purge all queues
      List("ingress-fhir", "ingress-hl7v3", "dlx-errors", "dlx-ingress", "dlx-transform", "transform-sql",
        "transform-hl7v3", "errors-ingress", "errors-transform", "errors-sql", "pond-seq", "unrouted") foreach (channel.queuePurge(_))
    }
    publish("sequencer", "pond", "1:100000")
  }

  after {
    // make sure all external processes are killed
    processMap foreach { case (_, p) => Try(p.destroy) }
  }

  "Tranzoom" should "not lose messages when a component is restarted" in {

    generateMessages(100).exitValue
    queuePurge("ingress-fhir") // ignore fhir messages as document-only counting is easier
    val numDocs = queueSize("ingress-hl7v3")

    val process = for {
      // start message processors
      _ <- future {
        processMap += ('xfm -> runTransformer)
        processMap += ('ingress -> runIngress)
        processMap += ('loader -> runLoader)
      }
      // wait for some messages to arrive so we know the loader is crunching
      _ <- future {
        waitFor(_ => queueSize("transform-sql") > 10)
      }
      // kill the loader
      _ <- future {
        logger.info("Killing loader")
        processMap.remove('loader) map { p => p.destroy; p.exitValue }
      }
      // restart the transformer and wait until ready
      x <- future {
        logger.info("Start another loader")
        processMap += ('loader -> runLoader)
        waitFor(_ => queueSize("transform-sql") == 0)
      }

    } yield x

    Await.result(process, maxWaitTime)

    // the loader should have claimed the sequence
    queueSize("pond-seq") should be(0)

    // kill all processes
    processMap foreach { case (_, p) => p.destroy; p.exitValue }

    // the loader should have returned the remaining sequence
    queueSize("pond-seq") should be(1)

    // check if all documents are either loaded or rejected by validation
    documentCount(lakeJdbc(lakeName)) + queueSize("errors-ingress") should be(numDocs)

  }

}

object TranzoomIntegrationSpec {
  import sys.process._
  import scala.language.postfixOps
  
  private val logger = LoggerFactory.getLogger(TranzoomIntegrationSpec.getClass)

  val maxWaitTime = 3600 seconds
  
  val pondName = "pond"
  val lakeName = "lake"

  val msgdir = "../../mgrid-messaging"
  val cdagendir = "../cda-generator"

  def runTransformer: Process =
    s"$msgdir/pyenv/bin/python $msgdir/integration/rabbitmq/transformer.py".run

  def runIngress: Process =
    "./target/start net.mgrid.tranzoom.ingress.IngressApplication".run

  def runLoader: Process = {
    val user = System.getProperty("user.name")
    Seq("./target/start",
      "-Dconfig.group-size=1",
      s"-Dconfig.pond.dbuser=${user}",
      s"-Dconfig.pond.dbname=${pondName}",
      s"-Dconfig.lake.dbuser=${user}",
      s"-Dconfig.lake.dbname=${lakeName}",
      "net.mgrid.tranzoom.ccloader.LoaderApplication").mkString(" ").run
  }

  def generateMessages(amount: Int): Process =
    shell(s"""cd $cdagendir && CDAGEN_NUMMSG=$amount ./start.sh""")

  def shell(cmd: String): Process = Seq("/bin/bash", "-c", cmd).run

  def waitFor[T](f: Unit => Boolean): Unit =
    Iterator.continually(f()).exists { done =>
      Thread.sleep(500)
      done
    }

}