<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:fhir="http://hl7.org/fhir"
  xmlns="urn:hl7-org:v3"
  exclude-result-prefixes="fhir xs xsl">

  <xsl:template match="/fhir:Practitioner">
    <PractitionerUpdate classCode="ACTN" moodCode="EVN" >
      <templateId root="TBD"/>
      <subject typeCode="SBJ">
        <healthCareProvider classCode="PROV">
          <xsl:apply-templates select="fhir:identifier" />
          <xsl:apply-templates select="fhir:specialty/fhir:coding" />
          <xsl:apply-templates select="fhir:period" />
          <healthCarePractitioner classCode="PSN" determinerCode="INSTANCE">
            <xsl:apply-templates select="fhir:identifier" />
            <xsl:apply-templates select="fhir:name" mode="human-name"/>
            <xsl:apply-templates select="fhir:telecom" />
            <xsl:apply-templates select="fhir:gender" />
            <xsl:apply-templates select="fhir:birthDate" />
            <xsl:apply-templates select="fhir:address" />
          </healthCarePractitioner>
          <xsl:apply-templates select="fhir:organization" />
        </healthCareProvider>
      </subject>
    </PractitionerUpdate>
  </xsl:template>

  <xsl:template match="fhir:organization">
    <issuingOrganization classCode="ORG" determinerCode="INSTANCE">
      <xsl:call-template name="convert-resource" />
    </issuingOrganization>
  </xsl:template>

</xsl:stylesheet>
