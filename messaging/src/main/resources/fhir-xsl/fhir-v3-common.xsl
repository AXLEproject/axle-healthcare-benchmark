<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:fhir="http://hl7.org/fhir"
  xmlns="urn:hl7-org:v3"
  exclude-result-prefixes="fhir xs xsl">
  
  <xsl:template match="fhir:identifier">
    <xsl:call-template name="convert-identifier" />
  </xsl:template>

  <xsl:template match="fhir:coding"> 
    <xsl:call-template name="convert-code" />
  </xsl:template>
  
  <xsl:template match="fhir:period">
    <xsl:call-template name="convert-role-period" />
  </xsl:template>
  
  <xsl:template match="fhir:period" mode="useable-period">
    <xsl:call-template name="convert-useable-period" />
  </xsl:template>
  
  <xsl:template match="fhir:name" mode="human-name">
    <xsl:call-template name="convert-human-name" />
  </xsl:template>

  <xsl:template match="fhir:name">
    <name>
      <xsl:value-of select="@value"/>
    </name>
  </xsl:template>

  <xsl:template match="fhir:address">
    <xsl:call-template name="convert-address" />
  </xsl:template>
  
  <xsl:template match="fhir:telecom">
    <xsl:call-template name="convert-telecom" />
  </xsl:template>

  <xsl:template match="fhir:gender">
    <xsl:call-template name="convert-gender" />
  </xsl:template>

  <xsl:template match="fhir:birthDate">
    <xsl:call-template name="convert-birthdate" />
  </xsl:template>

  <xsl:template match="fhir:deceasedBoolean">
    <deceasedInd>
      <xsl:attribute name="value">
        <xsl:value-of select="@value"/>
      </xsl:attribute>
    </deceasedInd>
  </xsl:template>
  
  <xsl:template match="fhir:use" mode="convert-use">
    <xsl:attribute name="use">
      <xsl:choose>
        <xsl:when test="@value = 'home' and ../fhir:system/@value = 'phone'">
          <xsl:text>HP</xsl:text>
        </xsl:when>
        <xsl:when test="@value = 'home'">
          <xsl:text>H</xsl:text>
        </xsl:when>
        <xsl:when test="@value = 'work'">
          <xsl:text>WP</xsl:text>
        </xsl:when>
        <xsl:when test="@value = 'old'">
          <xsl:text>OLD</xsl:text>
        </xsl:when>
        <xsl:when test="@value = 'mobile'">
          <xsl:text>MC</xsl:text>
        </xsl:when>
      </xsl:choose>
    </xsl:attribute>
  </xsl:template>
  
  <!-- named templates -->

  <xsl:template name="convert-date">
    <xsl:param name="value"/>
    <xsl:value-of select="translate($value,'-T:', '')" />
  </xsl:template>

  <xsl:template name="convert-codesystem">
    <xsl:param name="value"/>
    <xsl:choose>
      <xsl:when test="starts-with($value, 'urn:oid:')">
        <xsl:value-of select="substring-after($value,'urn:oid:')" />
      </xsl:when>
      <xsl:when test="$value = 'http://hl7.org/fhir/v3/AdministrativeGender'">
        <xsl:text>2.16.840.1.113883.5.1</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$value" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="convert-resource">
    <xsl:variable name="resource-id" select="fhir:extension[@url = 'http://portavita.eu/fhir/Identifier']/fhir:valueIdentifier"/>
    <xsl:if test="count($resource-id) = 0">
      <xsl:message terminate="yes">For resource references the extension http://portavita.eu/fhir/Identifier is required to enable mapping to HL7v3 identifiers.</xsl:message>
    </xsl:if>
    <xsl:call-template name="convert-identifier">
      <xsl:with-param name="node" select="fhir:extension[@url = 'http://portavita.eu/fhir/Identifier']/fhir:valueIdentifier" />
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="convert-identifier">
    <xsl:param name="node" select="."/>
    <id>
      <xsl:attribute name="root">
        <xsl:call-template name="convert-codesystem">
          <xsl:with-param name="value">
            <xsl:value-of select="$node/fhir:system/@value"/>
          </xsl:with-param>
        </xsl:call-template>
      </xsl:attribute>
      <xsl:attribute name="extension">
        <xsl:value-of select="$node/fhir:value/@value"/>
      </xsl:attribute>
    </id>
  </xsl:template>

  <xsl:template name="convert-human-name">
    <name>
      <xsl:call-template name="convert-human-name-use"/>
      <xsl:if test="fhir:given">
        <given>
          <xsl:value-of select="fhir:given/@value"/>
        </given>
      </xsl:if>
      <xsl:if test="fhir:family">
        <family>
          <xsl:if test="fhir:use/@value = 'maiden'">
            <xsl:attribute name="qualifier">BR</xsl:attribute>
          </xsl:if>
          <xsl:value-of select="fhir:family/@value"/>
        </family>
      </xsl:if>
      <xsl:if test="fhir:prefix">
        <prefix>
          <xsl:value-of select="fhir:prefix/@value"/>
        </prefix>
      </xsl:if>
      <xsl:value-of select="fhir:text/@value"/>
    </name>
  </xsl:template>
  
  <xsl:template name="convert-human-name-use">
    <xsl:variable name="use" select="fhir:use/@value"/>
    <xsl:choose>
      <xsl:when test="$use = 'official' or $use = 'usual'">
        <xsl:attribute name="use">L</xsl:attribute>
      </xsl:when>
      <xsl:when test="$use = 'maiden'">
        <xsl:attribute name="use">C</xsl:attribute>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="convert-code">
    <code>
      <xsl:attribute name="code">
        <xsl:value-of select="fhir:code/@value"/>
      </xsl:attribute>
      <xsl:attribute name="codeSystem">
        <xsl:call-template name="convert-codesystem">
          <xsl:with-param name="value">
            <xsl:value-of select="fhir:system/@value"/>
          </xsl:with-param>
        </xsl:call-template>
      </xsl:attribute>
      <xsl:if test="fhir:display/@value">
        <xsl:attribute name="displayName">
          <xsl:value-of select="fhir:display/@value"/>
        </xsl:attribute>
      </xsl:if>
    </code>
  </xsl:template>
  
  <xsl:template name="convert-telecom">
    <telecom>
      <xsl:attribute name="value">
        <xsl:value-of select="fhir:value/@value"/>
      </xsl:attribute>
      <xsl:apply-templates select="fhir:use" mode="convert-use" />
      <xsl:apply-templates select="fhir:period" mode="useable-period" />
    </telecom>
  </xsl:template>
  
  <xsl:template name="convert-role-period">
    <effectiveTime>
      <low>
        <xsl:attribute name="value">
          <xsl:call-template name="convert-date">
            <xsl:with-param name="value">
              <xsl:value-of select="fhir:start/@value"/>
            </xsl:with-param>
          </xsl:call-template>
        </xsl:attribute>
      </low>
    </effectiveTime>
  </xsl:template>

  <xsl:template name="convert-useable-period">
    <useablePeriod>
      <xsl:attribute name="value">
        <xsl:call-template name="convert-date">
          <xsl:with-param name="value">
            <xsl:value-of select="fhir:start/@value"/>
          </xsl:with-param>
        </xsl:call-template>
      </xsl:attribute>
    </useablePeriod>
  </xsl:template>

  <xsl:template name="convert-address">
    <addr>
      <xsl:apply-templates select="fhir:use" mode="convert-use" />
      <streetAddressLine>
        <xsl:value-of select="fhir:line/@value"/>
      </streetAddressLine>
      <city>
        <xsl:value-of select="fhir:city/@value"/>
      </city>
      <postalCode>
        <xsl:value-of select="fhir:zip/@value"/>
      </postalCode>
      <xsl:if test="fhir:country">
        <country>
          <xsl:value-of select="fhir:country/@value"/>
        </country>
      </xsl:if>
      <xsl:apply-templates select="fhir:period" mode="useable-period" />
    </addr>
  </xsl:template>
  
  <xsl:template name="convert-gender">
    <administrativeGenderCode>
      <xsl:attribute name="code">
        <xsl:value-of select="fhir:coding/fhir:code/@value"/>
      </xsl:attribute>
      <xsl:attribute name="codeSystem">
        <xsl:call-template name="convert-codesystem">
          <xsl:with-param name="value">
            <xsl:value-of select="fhir:coding/fhir:system/@value"/>
          </xsl:with-param>
        </xsl:call-template>
      </xsl:attribute>
        <xsl:if test="fhir:coding/fhir:system/@value = 'http://hl7.org/fhir/v3/AdministrativeGender'">
          <xsl:attribute name="codeSystemName">
            <xsl:text>HL7 AdministrativeGender</xsl:text>
          </xsl:attribute>
          <!-- http://hl7.org/implement/standards/fhir/v3/AdministrativeGender/ -->
          <xsl:choose>
            <xsl:when test="fhir:coding/fhir:code/@value = 'F'">
              <xsl:attribute name="displayName">
              <xsl:text>Female</xsl:text>
            </xsl:attribute>
            </xsl:when>
            <xsl:when test="fhir:coding/fhir:code/@value = 'M'">
              <xsl:attribute name="displayName">
                <xsl:text>Male</xsl:text>
              </xsl:attribute>
            </xsl:when>
            <xsl:when test="fhir:coding/fhir:code/@value = 'UN'">
              <xsl:attribute name="displayName">
                <xsl:text>Undifferentiated</xsl:text>
              </xsl:attribute>
            </xsl:when>
          </xsl:choose>
        </xsl:if>
    </administrativeGenderCode>
  </xsl:template>

  <xsl:template name="convert-birthdate">
    <birthTime>
      <xsl:attribute name="value">
        <xsl:call-template name="convert-date">
          <xsl:with-param name="value">
            <xsl:value-of select="@value"/>
          </xsl:with-param>
        </xsl:call-template>
      </xsl:attribute>
    </birthTime>
  </xsl:template>

</xsl:stylesheet>
