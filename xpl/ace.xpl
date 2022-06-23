<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc"
  xmlns:c="http://www.w3.org/ns/xproc-step" 
  xmlns:tr="http://transpect.io"
  xmlns:cx="http://xmlcalabash.com/ns/extensions"
  xmlns:pxf="http://exproc.org/proposed/steps/file"
  xmlns:svrl="http://purl.oclc.org/dsdl/svrl"
  version="1.0" 
  name="ace-daisy"
  type="tr:ace-daisy">
  
  <p:documentation>
    XProc wrapper for DAISY's ACE accessibility checker.
    Default output are the validation messages as SVRL report 
    and brief SVRL summary. If the a11y-htmlreport option is 
    active, then a separate HTML report will be created.
  </p:documentation>
  
  <p:output port="report">
    <p:documentation>
      SVRL report
    </p:documentation>
    <p:pipe port="result" step="choose"/>
  </p:output>
  
  <p:output port="summary">
    <p:documentation>
      SVRL report just summarized in one validation message.
    </p:documentation>
    <p:pipe port="summary" step="choose"/>
  </p:output>
  
  <p:option name="href">
    <p:documentation>
      Path to EPUB file. A separate ACE report would be created in the same directory.
    </p:documentation>
  </p:option>
  
  <p:option name="ace" select="'dist/bin/ace.js'">
    <p:documentation>
      Path to ace.js, usually stored in your node_modules directory.
    </p:documentation>
  </p:option>
  
  <p:option name="lang" select="'en'">
    <p:documentation>
      Language code for localized messages (e.g. "fr"), default is "en".
    </p:documentation>
  </p:option>
  
  <p:option name="rule-family-name" select="'epubcheck 4.2.6'">
    <p:documentation>
      Rule family name. Create a specific name or assign a name of 
      an existing rule family where you want to include the messages.
    </p:documentation>
  </p:option>
  
  <p:option name="a11y-htmlreport" select="'yes'">
    <p:documentation>
      Creates a separate accessibility HTML report. 
    </p:documentation>
  </p:option>
  
  <p:option name="debug" select="'no'">
    <p:documentation>
      Whether do store debug information
    </p:documentation>
  </p:option>
  
  <p:option name="debug-dir-uri" select="'debug'">
    <p:documentation>
      URI where to store the debug information
    </p:documentation>
  </p:option>
  
  <p:import href="http://xmlcalabash.com/extension/steps/library-1.0.xpl"/>
  <p:import href="http://transpect.io/xproc-util/file-uri/xpl/file-uri.xpl"/>
  <p:import href="http://transpect.io/xproc-util/store-debug/xpl/store-debug.xpl"/>
  
  <tr:file-uri name="get-epub-path">
    <p:with-option name="filename" select="$href"/>
    <p:input port="catalog">
      <p:document href="http://this.transpect.io/xmlcatalog/catalog.xml"/>
    </p:input>
    <p:input port="resolver">
      <p:document href="http://transpect.io/xslt-util/xslt-based-catalog-resolver/xsl/resolve-uri-by-catalog.xsl"/>
    </p:input>
  </tr:file-uri>
  
  <tr:file-uri name="get-outdir-path">
    <p:with-option name="filename" select="concat(replace(/c:result/@local-href, '^(.+)/.+?$', '$1'), '/a11y')"/>
    <p:input port="catalog">
      <p:document href="http://this.transpect.io/xmlcatalog/catalog.xml"/>
    </p:input>
    <p:input port="resolver">
      <p:document href="http://transpect.io/xslt-util/xslt-based-catalog-resolver/xsl/resolve-uri-by-catalog.xsl"/>
    </p:input>
  </tr:file-uri>
  
  <tr:file-uri name="get-ace-path">
    <p:with-option name="filename" select="$ace"/>
    <p:input port="catalog">
      <p:document href="http://this.transpect.io/xmlcatalog/catalog.xml"/>
    </p:input>
    <p:input port="resolver">
      <p:document href="http://transpect.io/xslt-util/xslt-based-catalog-resolver/xsl/resolve-uri-by-catalog.xsl"/>
    </p:input>
  </tr:file-uri>
  
  <pxf:info name="epub-info" fail-on-error="true">
    <p:with-option name="href" select="/*/@local-href">
      <p:pipe port="result" step="get-epub-path"/>
    </p:with-option>
  </pxf:info>
  
  <p:sink/>
  
  <pxf:info name="ace-info" fail-on-error="true">
    <p:with-option name="href" select="/*/@local-href">
      <p:pipe port="result" step="get-ace-path"/>
    </p:with-option>
  </pxf:info>
  
  <p:choose name="choose">
    <p:variable name="epub-readable" select="c:file/@readable eq 'true'"/>
    <p:variable name="ace-readable" select="c:file/@readable eq 'true'">
      <p:pipe port="result" step="ace-info"/>
    </p:variable>
    <p:variable name="ace-path" select="/c:result/@os-path">
      <p:pipe port="result" step="get-ace-path"/>
    </p:variable>
    <p:variable name="epub-path" select="/c:result/@os-path">
      <p:pipe port="result" step="get-epub-path"/>
    </p:variable>
    <p:variable name="outdir" select="/c:result/@os-path">
      <p:pipe port="result" step="get-outdir-path"/>
    </p:variable>
    <p:variable name="run" select="string-join(($ace-path, 
                                                '--force -l',
                                                $lang,
                                                ('-o', $outdir)[$a11y-htmlreport eq 'yes'],
                                                $epub-path), ' ')"/>
    <p:when test="$epub-readable and $ace-readable">  
      <p:output port="result" primary="true"/>
      <p:output port="summary" primary="false">
        <p:pipe port="result" step="ace-summary"/>
      </p:output>
      
      <cx:message>
        <p:with-option name="message" select="'[info] epub path: ', $epub-path"/>
      </cx:message>
      
      <cx:message>
        <p:with-option name="message" select="'[info] ace path: ', $ace-path"/>
      </cx:message>
      
      <cx:message>
        <p:with-option name="message" select="'[info] output dir: ', $outdir"/>
      </cx:message>
      
      <cx:message>
        <p:with-option name="message" select="'[info] run: ', $run"/>
      </cx:message>
      
      <p:exec name="run-ace" 
              result-is-xml="false" 
              errors-is-xml="false" 
              wrap-result-lines="true" 
              wrap-error-lines="false">
        <p:input port="source">
          <p:empty/>
        </p:input>
        <p:with-option name="command" select="'node'"/>
        <p:with-option name="args" 
                       select="$run"/>
      </p:exec>
      
      <tr:store-debug pipeline-step="ace/00_exec">
        <p:with-option name="active" select="$debug"/>
        <p:with-option name="base-uri" select="$debug-dir-uri"/>
      </tr:store-debug>
      
      <p:xslt initial-mode="normalize-exec-output" name="normalize" cx:depends-on="run-ace">
        <p:input port="parameters">
          <p:empty/>
        </p:input>
        <p:input port="stylesheet">
          <p:document href="../xsl/json2svrl.xsl"/>
        </p:input>
      </p:xslt>
      
      <p:xslt initial-mode="json2svrl" name="json2svrl" cx:depends-on="run-ace">
        <p:input port="stylesheet">
          <p:document href="../xsl/json2svrl.xsl"/>
        </p:input>
        <p:with-param name="rule-family-name" select="$rule-family-name"/>
        <p:with-param name="epub-path" select="$epub-path"/>
        <p:with-param name="outdir-uri" select="/c:result/@local-href">
          <p:pipe port="result" step="get-outdir-path"/>
        </p:with-param>
        <p:with-param name="a11y-htmlreport" select="$a11y-htmlreport"/>
      </p:xslt>
      
      <p:sink/>
      
      <p:identity name="ace-summary">
        <p:input port="source" select="/cx:documents/svrl:schematron-output[@title eq 'ace-summary']">
          <p:pipe port="result" step="json2svrl"/>
        </p:input>
      </p:identity>
      
      <tr:store-debug pipeline-step="ace/04_ace-summary">
        <p:with-option name="active" select="$debug"/>
        <p:with-option name="base-uri" select="$debug-dir-uri"/>
      </tr:store-debug>
      
      <p:sink/>
      
      <p:identity name="ace-report">
        <p:input port="source" select="/cx:documents/svrl:schematron-output[@title eq 'ace-report']">
          <p:pipe port="result" step="json2svrl"/>
        </p:input>
      </p:identity>
      
      <tr:store-debug pipeline-step="ace/08_ace-report">
        <p:with-option name="active" select="$debug"/>
        <p:with-option name="base-uri" select="$debug-dir-uri"/>
      </tr:store-debug>
      
    </p:when>
    <p:otherwise>
      <p:output port="result" primary="true"/>
      <p:output port="summary" primary="false">
        <p:pipe port="result" step="add-rule-family"/>
      </p:output>
      
      <p:add-attribute match="/c:errors" attribute-name="tr:rule-family" name="add-rule-family">
        <p:with-option name="attribute-value" select="$rule-family-name"/>
        <p:input port="source">
          <p:inline>
            <c:errors>
              <c:error code="ace-failed" role="fatal-error">failed while creating the accessibility report.</c:error>
            </c:errors>
          </p:inline>
        </p:input>
      </p:add-attribute>
      
    </p:otherwise>
  </p:choose>
  
</p:declare-step>