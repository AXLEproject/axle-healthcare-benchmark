import sbt._
import Keys._

object B extends Build
{
  lazy val root =
    Project("root", file("."))
      .configs(IntTest)
      .settings(inConfig(IntTest)(Defaults.testTasks): _*)
      .settings(
        testOptions in Test := Seq(Tests.Filter(unitFilter)),
        testOptions in IntTest := Seq(Tests.Filter(itFilter))
      )

  def unitFilter(name: String): Boolean = (name endsWith "Spec") && !itFilter(name)
  def itFilter(name: String): Boolean = name endsWith "IntegrationSpec"

  lazy val IntTest = config("inttest") extend(Test)
}
