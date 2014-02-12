<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:fhir="http://hl7.org/fhir"
  xmlns="urn:hl7-org:v3"
  exclude-result-prefixes="fhir xs xsl">
  
  <xsl:namespace-alias stylesheet-prefix="fhir" result-prefix="hl7v3" />
  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
  
  <xsl:include href="fhir-v3-common.xsl" />
  <xsl:include href="fhir-v3-orga-transform.xsl" />
  <xsl:include href="fhir-v3-prac-transform.xsl" />
  <xsl:include href="fhir-v3-pat-transform.xsl" />

</xsl:stylesheet>
