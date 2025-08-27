<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:math="http://www.w3.org/2005/xpath-functions/math"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:c="http://www.w3.org/ns/xproc-step"
  xmlns:s="http://purl.oclc.org/dsdl/schematron"
  xmlns:svrl="http://purl.oclc.org/dsdl/svrl"
  xmlns:tr="http://transpect.io"
  xmlns:fn="http://www.w3.org/2005/xpath-functions"
  exclude-result-prefixes="xs math" 
  version="3.0">
  
  <xsl:output indent="yes"/>
  
  <!-- this step produces two svrl documents, a brief summary
       and an extensive report
  -->
  <!-- you can designate a rule family to attach the 
       a11y summary to an existing rule family, e.g. epubcheck -->
  <xsl:param name="rule-family-name" select="'epubcheck 4.2.6'"/>
  <xsl:param name="epub-path" select="'myFile.epub'"/>
  <xsl:param name="outdir-uri" select="'out'"/>
  <xsl:param name="a11y-htmlreport" select="'no'"/>
  <xsl:param name="severity-override" select="''"/>
  <xsl:param name="add-ace-version" select="'no'"/>
  
  <xsl:template match="/" mode="json2svrl">
    <xsl:variable name="doc" as="document-node(element(fn:map))" 
                  select="json-to-xml(unparsed-text(concat($outdir-uri, '/report.json')))"/>
    <xsl:variable name="rule-family-name-expanded" as="xs:string" 
                  select="if ($add-ace-version = ('yes', 'true'))
                          then
                             concat(
                                $rule-family-name,
                                ' (',
                                $doc/fn:map/fn:map[@key eq 'earl:assertedBy']/fn:string[@key = 'doap:name'],
                                ' ',
                                $doc/fn:map/fn:map[@key eq 'earl:assertedBy']/fn:map[@key eq 'doap:release']/fn:string[@key = 'doap:revision'],
                                ')')
                          else $rule-family-name"/>
    <cx:documents xmlns:cx="http://xmlcalabash.com/ns/extensions">
      <xsl:apply-templates select="$doc/fn:map/fn:array[@key eq 'assertions']" mode="svrl-summary">
        <xsl:with-param name="rule-family-name-expanded" select="$rule-family-name-expanded" tunnel="yes"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="$doc/fn:map/fn:array[@key eq 'assertions']" mode="svrl-combined">
        <xsl:with-param name="rule-family-name-expanded" select="$rule-family-name-expanded" tunnel="yes"/>
      </xsl:apply-templates>
    </cx:documents>  
  </xsl:template>
  
  <xsl:template match="/fn:map/fn:array[@key eq 'assertions']" mode="svrl-summary">
    <xsl:param name="rule-family-name-expanded" tunnel="yes"/>
    <xsl:variable name="all-impacts" as="element(fn:string)*" 
                  select="//fn:map[@key eq 'earl:test']/fn:string[@key eq 'earl:impact']"/>
    <svrl:schematron-output title="ace-summary"
                            tr:rule-family="{$rule-family-name-expanded}"
                            tr:step-name="accessibility">
      <xsl:if test="$all-impacts = ('serious', 'critical', 'moderate')">
        <svrl:failed-assert test="{$epub-path}"
                            id="accessibility"
                            role="{($severity-override[normalize-space(.)] ,tr:most-serious-impact($all-impacts))[1]}"
                            location="BC_orphans">
          <s:span class="srcpath">BC_orphans</s:span>
          <xsl:call-template name="group-issues">
            <xsl:with-param name="report-type" select="'summary'" as="xs:string"/>
          </xsl:call-template>
        </svrl:failed-assert>
      </xsl:if>  
    </svrl:schematron-output>
  </xsl:template>
  
  <xsl:template match="/fn:map/fn:array[@key eq 'assertions']" mode="svrl-combined">
    <xsl:param name="rule-family-name-expanded" tunnel="yes"/>
    <xsl:variable name="issues">  
      <xsl:call-template name="group-issues">
        <xsl:with-param name="report-type" select="'combined'" as="xs:string"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:element name="{if ($issues/*) then 'svrl:schematron-output' else 'c:ok'}">
      <xsl:attribute name="title" select="'ace-report'"/>
      <xsl:attribute name="tr:rule-family" select="$rule-family-name-expanded"/>
      <xsl:attribute name="tr:step-name" select="'accessibility'"/>
      <xsl:sequence select="$issues"/>
    </xsl:element> 
  </xsl:template>
  
  <xsl:template name="group-issues">
    <xsl:param name="report-type" as="xs:string"/>
    <xsl:for-each-group select=".//fn:map[fn:string[@key eq '@type'][. eq 'earl:assertion']][fn:map[@key eq 'earl:test']]" 
                        group-by="fn:map[@key eq 'earl:test']/fn:string[@key eq 'dct:title']">
      <xsl:variable name="title"  as="xs:string"
                    select="fn:current-grouping-key()"/>
      <xsl:variable name="status" as="element(fn:string)"
                    select="fn:map[@key eq 'earl:result']/fn:string[@key eq 'earl:outcome']"/>
      <xsl:variable name="impact" as="element(fn:string)"
                    select="fn:map[@key eq 'earl:test']/fn:string[@key eq 'earl:impact']"/>
      <xsl:variable name="messages" as="element(fn:string)+"
                    select="fn:map[@key eq 'earl:result']/fn:string[@key eq 'dct:description'],
                            fn:map[@key eq 'earl:test']/fn:map[@key eq 'help']/fn:string[@key eq 'dct:description']"/>
      <xsl:variable name="count" as="xs:integer"
                    select="count(current-group())"/>
      <xsl:choose>
        <xsl:when test="$report-type eq 'summary'">
          <span xmlns="http://www.w3.org/1999/xhtml" class="issue">
            <xsl:value-of select="$title"/>
          </span>
          <br xmlns="http://www.w3.org/1999/xhtml"/>
          <s:span class="ace">
            <xsl:sequence select="string-join($messages, '. ')"/>
            <xsl:value-of select="fn:concat('. (count:', $count, ')')"/>
          </s:span> 
        </xsl:when>
        <xsl:when test="'combined'">
          <svrl:failed-assert test="{$epub-path}"
                              id="{$title}"
                              role="{($severity-override[normalize-space(.)], tr:ace-impact-to-svrl-role($impact))[1]}"
                              location="BC_orphans">
            <svrl:text>
              <s:span class="srcpath">BC_orphans</s:span>
              <s:span class="ace">
                <xsl:sequence select="string-join($messages, '. ')"/>
                <xsl:value-of select="fn:concat(' (', $count, ')')"/>                
              </s:span>
            </svrl:text>
          </svrl:failed-assert>    
        </xsl:when>
      </xsl:choose>
    </xsl:for-each-group>
  </xsl:template>
  
  <xsl:function name="tr:ace-impact-to-svrl-role" as="xs:string">
    <xsl:param name="ace-impact" as="xs:string"/>
    <xsl:sequence select="('info'[$ace-impact eq 'minor'],
                           'warning'[$ace-impact eq 'moderate'],
                           'error'[$ace-impact eq 'serious'],
                           'fatal-error'[$ace-impact eq 'critical'])"/>
  </xsl:function>
  
  <xsl:function name="tr:most-serious-impact" as="xs:string">
    <xsl:param name="ace-impacts" as="xs:string*"/>
    <xsl:sequence select="($ace-impacts[. eq 'critical'],
                           $ace-impacts[. eq 'serious'],
                           $ace-impacts[. eq 'moderate'],
                           $ace-impacts[. eq 'minor']
                           )[1]"/>
  </xsl:function>
  
</xsl:stylesheet>