<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:fhir="http://hl7.org/fhir"
  xmlns="urn:hl7-org:v3"
  exclude-result-prefixes="fhir xs xsl">
  
  <xsl:template match="/fhir:Organization">
    <OrganizationUpdate classCode="ACTN" moodCode="EVN" >
      <participation typeCode="PART">
        <subject classCode="IDENT">
          <scopingOrganization classCode="ORG" determinerCode="INSTANCE">
            <xsl:apply-templates select="fhir:identifier" />
            <xsl:apply-templates select="fhir:type/fhir:coding" />
            <xsl:apply-templates select="fhir:name" />
            <xsl:apply-templates select="fhir:telecom" />
            <xsl:apply-templates select="fhir:address" />
            <xsl:apply-templates select="fhir:partOf" />
          </scopingOrganization>
        </subject>
      </participation>
    </OrganizationUpdate>
  </xsl:template>

  <xsl:template match="fhir:partOf">
    <asPartOfWhole classCode="PART">
      <wholeParent classCode="ORG" determinerCode="INSTANCE">
        <xsl:call-template name="convert-resource" />
      </wholeParent>
    </asPartOfWhole>
  </xsl:template>

</xsl:stylesheet>
