import com.typesafe.sbt.SbtStartScript

Seq(SbtStartScript.startScriptForClassesSettings: _*)

name := "tranzoom-messaging"

version := "1.0"

scalaVersion := "2.10.3"

scalacOptions ++= Seq("-unchecked", "-deprecation", "-feature")

libraryDependencies ++= Seq(
  "org.springframework.integration" % "spring-integration-core" % "3.0.1.RELEASE",
  "org.springframework.integration" % "spring-integration-xml" % "3.0.1.RELEASE",
  "org.springframework.integration" % "spring-integration-amqp" % "3.0.1.RELEASE",
  "org.postgresql" % "postgresql" % "9.3-1100-jdbc41",
  "commons-dbcp" % "commons-dbcp" % "1.4",
  "commons-pool" % "commons-pool" % "1.5.4",
  "org.slf4j" % "slf4j-api" % "1.7.5",
  "org.slf4j" % "slf4j-log4j12" % "1.7.5",
  "org.scalatest" % "scalatest_2.10" % "2.0" % "test",
  "org.mockito" % "mockito-all" % "1.9.5" % "test"
)
