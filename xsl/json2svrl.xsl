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
  
  <xsl:template match="/c:result|c:line" mode="normalize-exec-output">
    <xsl:copy>
      <xsl:apply-templates mode="#current"/>  
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="c:line[following-sibling::c:line[. eq '{']]
                      |c:line[preceding-sibling::c:line[. eq '}']]"  mode="normalize-exec-output">
    
  </xsl:template>
  
  <xsl:template match="text()" mode="normalize-exec-output">
    <xsl:value-of select="replace(., '\p{Cc}', '')"/>
  </xsl:template>
  
  <xsl:template match="/" mode="json2svrl">
    <xsl:variable name="doc" as="document-node(element(fn:map))" 
                  select="if($a11y-htmlreport eq 'yes') 
                          then json-to-xml(unparsed-text(concat($outdir-uri, '/report.json')))
                          else json-to-xml(xs:string(.))"/>
    <cx:documents xmlns:cx="http://xmlcalabash.com/ns/extensions">
      <xsl:apply-templates select="$doc/fn:map/fn:array[@key eq 'assertions']" mode="svrl-summary"/>
      <xsl:apply-templates select="$doc/fn:map/fn:array[@key eq 'assertions']" mode="svrl-combined"/>
    </cx:documents>  
  </xsl:template>
  
  <xsl:template match="/fn:map/fn:array[@key eq 'assertions']" mode="svrl-summary">
    <xsl:variable name="all-impacts" as="element(fn:string)*" 
                  select="//fn:map[@key eq 'earl:test']/fn:string[@key eq 'earl:impact']"/>
    <svrl:schematron-output title="ace-summary"
                            tr:rule-family="{$rule-family-name}"
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
    <svrl:schematron-output title="ace-report"
                            tr:rule-family="{$rule-family-name}"
                            tr:step-name="accessibility">
      <xsl:call-template name="group-issues">
        <xsl:with-param name="report-type" select="'combined'" as="xs:string"/>
      </xsl:call-template>
    </svrl:schematron-output>
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