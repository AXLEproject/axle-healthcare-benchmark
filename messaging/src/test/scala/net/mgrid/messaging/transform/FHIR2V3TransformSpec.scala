/**
 * Copyright (c) 2013, 2014, MGRID BV Netherlands
 */
package test.scala.net.mgrid.messaging.transform

import org.scalatest.FlatSpec
import org.springframework.context.support.ClassPathXmlApplicationContext
import org.springframework.integration.MessageChannel
import org.springframework.integration.core.PollableChannel
import org.springframework.integration.message.GenericMessage
import java.io.File
import javax.xml.transform.TransformerFactory
import javax.xml.transform.stream.StreamSource
import scala.xml.Source
import org.springframework.xml.transform.StringResult
import scala.xml.XML
import javax.xml.transform.TransformerException

class FHIR2V3TransformSpec extends FlatSpec {

  "FHIR to v3 transform" should "transform Organization updates" in {
    testFile("fhir2v3_0001_orga_input_OK.xml")
    testFile("fhir2v3_0003_orga_input_OK.xml")
  }

  it should "transform Practitioner updates" in {
    testFile("fhir2v3_0002_prac_input_OK.xml")
    testFile("fhir2v3_0006_prac_input_OK.xml")
  }

  it should "transform Patient updates" in {
    testFile("fhir2v3_0004_pat_input_OK.xml")
    testFile("fhir2v3_0005_pat_input_invalidresref.xml")
  }

  // shared variables and helpers

  val xsl = new File("src/main/resources/fhir-xsl/fhir-v3-transform.xsl")
  val template = TransformerFactory.newInstance.newTemplates(new StreamSource(xsl))
  val transformer = template.newTransformer()
  val okInput = """(fhir2v3_\d{4}_[a-zA-Z0-9]+)_input_OK\.xml""".r // regexp to categorize input files

  private def testFile(filename: String): Unit = {
    val s = new StreamSource(new File(s"test-data/$filename"))
    val result = new StringResult()

    filename match {
      case okInput(prefix) => {
        import scala.xml.Utility.trim

        transformer.transform(s, result)

        val output = XML.loadString(result.toString())
        val expected = XML.loadFile(s"test-data/${prefix}_expected.xml")

        assert(trim(output) == trim(expected), s"Output $output did not match expected $expected")
      }
      case _ => intercept[TransformerException] { // we expect the transform to fail
        transformer.transform(s, result)
      }
    }
  }
}
