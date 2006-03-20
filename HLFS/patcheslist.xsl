<?xml version='1.0' encoding='ISO-8859-1'?>

<!-- $Id$ -->
<!-- Get list of patch files from the HLFS Book -->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0">

  <xsl:output method="text"/>

  <!-- What libc implentation must be used? -->
  <xsl:param name="model" select="glibc"/>

  <!-- No text needed -->
  <xsl:template match="//text()">
    <xsl:text/>
  </xsl:template>

  <!-- Just grab the url from the patches.xml file -->
  <xsl:template match="//ulink">
    <xsl:if test="ancestor::varlistentry[@condition=$model]
            or not(ancestor::varlistentry[@condition])">
       <xsl:value-of select="@url"/>
       <xsl:text>&#x0a;</xsl:text>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
