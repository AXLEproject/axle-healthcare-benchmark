<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:fhir="http://hl7.org/fhir"
  xmlns="urn:hl7-org:v3"
  exclude-result-prefixes="fhir xs xsl">

  <xsl:template match="/fhir:Patient">
    <PatientUpdate classCode="ACTN" moodCode="EVN">
      <recordTarget typeCode="RCT">
        <patient classCode="PAT">
          <xsl:apply-templates select="fhir:identifier[count(fhir:period) = 0]"/>
          <patientPerson classCode="PSN" determinerCode="INSTANCE">
            <xsl:apply-templates select="fhir:identifier[count(fhir:period) = 0]"/>
            <xsl:apply-templates select="fhir:name" mode="human-name"/>
            <xsl:apply-templates select="fhir:telecom"/>
            <xsl:apply-templates select="fhir:gender"/>
            <xsl:apply-templates select="fhir:birthDate"/>
            <xsl:apply-templates select="fhir:deceasedBoolean"/>
            <xsl:apply-templates select="fhir:address"/>
            <xsl:apply-templates select="fhir:identifier[fhir:period]" mode="policy-holder"/>
            <xsl:apply-templates select="fhir:careProvider"/>
          </patientPerson>
          <xsl:apply-templates select="fhir:managingOrganization"/>
        </patient>
      </recordTarget>
    </PatientUpdate>
  </xsl:template>

  <xsl:template match="fhir:identifier[fhir:period]" mode="policy-holder">
    <asPolicyHolder classCode="POLHOLD">
      <xsl:call-template name="convert-identifier" />
      <xsl:apply-templates select="fhir:period" />
      <xsl:apply-templates select="fhir:assigner" />
    </asPolicyHolder>
  </xsl:template>

  <xsl:template match="fhir:assigner">
    <underwritingInsurer classCode="ORG" determinerCode="INSTANCE">
      <xsl:call-template name="convert-resource" />
    </underwritingInsurer>
  </xsl:template>

  <xsl:template match="fhir:careProvider">
    <asCareGiver classCode="CAREGIVER">
      <xsl:apply-templates select="fhir:extension" />
      <careGiverScoper classCode="PSN" determinerCode="INSTANCE">
        <xsl:call-template name="convert-resource" />
      </careGiverScoper>
    </asCareGiver>
  </xsl:template>
  
  <xsl:template match="fhir:managingOrganization">
    <providerOrganization classCode="ORG" determinerCode="INSTANCE">
      <xsl:call-template name="convert-resource" />
    </providerOrganization>
  </xsl:template>

  <!-- Extensions -->

  <xsl:template match="fhir:extension[@url = 'http://portavita.eu/fhir/CareProviderRole']">
    <code>
      <xsl:attribute name="code">
        <xsl:value-of select="fhir:valueString/@value"/>
      </xsl:attribute>
    </code>
  </xsl:template>

  <xsl:template match="fhir:extension[@url = 'http://portavita.eu/fhir/CareProviderFromTime']">
    <effectiveTime>
      <low>
        <xsl:attribute name="value">
          <xsl:call-template name="convert-date">
            <xsl:with-param name="value">
              <xsl:value-of select="fhir:valueDateTime/@value"/>
            </xsl:with-param>
          </xsl:call-template>
        </xsl:attribute>
      </low>
    </effectiveTime>
  </xsl:template>

</xsl:stylesheet>
