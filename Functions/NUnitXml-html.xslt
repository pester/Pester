<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output omit-xml-declaration="yes" method="xml" doctype-system="" doctype-public="" indent="yes"/>
  <xsl:strip-space elements="*" />

  <xsl:param name="powerShellVersion" select="''" />
  <xsl:param name="testRunTitle" select="'Pester Spec Run'" />
  <xsl:param name="mainGroupName" select="'Files'" />
  <xsl:param name="subGroupName" select="'Groups'" />
  <xsl:param name="singleGroupName" select="'Specs'" />

  <xsl:template match="/">
    <html>
      <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
        <title>HTML Report</title>
        <style>
          body {
            font-size: 12pt;
            font-family: Georgia;
          }
          h1 { font-size:16pt; margin:14pt 0pt 20pt 0pt; padding:0pt 0pt 4pt 0pt; }
          details { font-size:12pt; margin:7pt; padding:7pt 14pt 7pt 14pt; }
          h2 { font-size:12pt; margin:12pt 0pt 0pt 0pt; padding:0pt 0pt 3pt 0pt; }
          .success      { background-color: #c5d88a; }
          .inconclusive { background-color: #eaec2d; }
          .failure      { background-color: #d88a8a; }
          .failureMessage { background-color: #edbbbb; color:black; margin:0px; padding:5pt 0pt 5pt 5pt; }
          .inconclusiveMessage { background-color: #ebec98; color:black; margin:0px; padding:5pt 0pt 5pt 5pt; }
          .widthHeader  { width: 60pt; }
          .widthHeader2 { width: 80pt; }
          hr { width: 100%; height: 1pt; margin:14pt 0px 0px 0px; color: grey; background: grey; }
          pre {
              font-family: Consolas,monospace;
              font-size: 12pt;
              white-space: pre-wrap;
              white-space: -moz-pre-wrap;
              white-space: -pre-wrap;
              white-space: -o-pre-wrap;
              word-wrap: break-word;
          }
          table { border-spacing: 0; }
          td, th { padding: 0pt 5pt 0pt 0pt; }
          th, td { text-align: right; }
          th.left, td.left { text-align: left; }
          #overview { overflow:hidden; }
          #results  { float: left; margin-bottom: 12pt; }
          #summary  { float: right; clear:right; margin-top: 14pt; }
        </style>
      </head>
      <body>
        <!-- Apply root element transformation -->
        <xsl:apply-templates select="//test-results" />
      </body>
    </html>
  </xsl:template>

  <!-- Transformation for root element -->
  <xsl:template match="test-results">
    <div id="overview">
      <div id="results">
        <h1><xsl:value-of select="$testRunTitle" /></h1>
        <table>
          <tr>
            <td class="widthHeader2"><xsl:text disable-output-escaping="yes">&amp;#160;</xsl:text></td>
            <th class="widthHeader">Total</th>
            <th class="success widthHeader">Passed</th>
            <th class="inconclusive widthHeader">Skipped</th>
            <th class="failure widthHeader">Failed</th>
          </tr>
          <tr>
            <th class="left"><xsl:value-of select="$mainGroupName" /><xsl:text>:</xsl:text></th>
            <td><xsl:value-of select="count(node()/results/test-suite)"/></td>
            <td class="success">
              <xsl:value-of select="count(node()/results/test-suite[count(node()//test-case[@result='Success']) > 0 and count(node()//test-case[@result='Success']) = count(node()//test-case)])"/>
            </td>
            <td class="inconclusive">
              <xsl:value-of select="count(node()/results/test-suite[(count(node()//test-case[@result='Inconclusive']) > 0 and count(node()//test-case[@result='Failure']) = 0) or (count(node()//test-case) = 0)])"/>
            </td>
            <td class="failure">
              <xsl:value-of select="count(node()/results/test-suite[count(node()//test-case[@result='Failure']) > 0])"/>
            </td>
          </tr>
          <tr>
            <th class="left"><xsl:value-of select="$subGroupName" /><xsl:text>:</xsl:text></th>
            <td><xsl:value-of select="count(node()/results/test-suite/results/test-suite)"/></td>
            <td class="success">
              <xsl:value-of select="count(node()/results/test-suite/results/test-suite[count(node()//test-case[@result='Success']) > 0 and count(node()//test-case[@result='Success']) = count(node()//test-case)])"/>
            </td>
            <td class="inconclusive">
              <xsl:value-of select="count(node()/results/test-suite/results/test-suite[(count(node()//test-case[@result='Inconclusive']) > 0 and count(node()//test-case[@result='Failure']) = 0) or (count(node()//test-case) = 0)])"/>
            </td>
            <td class="failure">
              <xsl:value-of select="count(node()/results/test-suite/results/test-suite[count(node()//test-case[@result='Failure']) > 0])"/>
            </td>
          </tr>
          <tr>
            <th class="left"><xsl:value-of select="$singleGroupName" /><xsl:text>:</xsl:text></th>
            <td>
              <xsl:value-of select="count(//test-case)"/>
            </td>
            <td class="success">
              <xsl:value-of select="count(//test-case[@result='Success'])"/>
            </td>
            <td class="inconclusive">
              <xsl:value-of select="count(//test-case[@result='Inconclusive'])"/>
            </td>
            <td class="failure">
              <xsl:value-of select="count(//test-case[@result='Failure'])"/>
            </td>
          </tr>
        </table>
      </div>
      <div id="summary">
        <table>
          <xsl:if test="$powerShellVersion != ''">
            <tr>
              <th>PowerShell version:</th>
              <td class="left"><xsl:value-of select="$powerShellVersion"/></td>
            </tr>
          </xsl:if>
          <tr>
            <th>Operating system:</th>
            <td class="left">
              <xsl:value-of select="substring-before(environment/@platform,'|')"/>
            </td>
          </tr>
          <tr>
            <th>Version:</th>
            <td class="left">
              <xsl:value-of select="environment/@os-version"/>
            </td>
          </tr>
          <tr>
            <th>User:</th>
            <td class="left">
              <xsl:value-of select="environment/@user"/>
              <xsl:text>@</xsl:text>
              <xsl:value-of select="environment/@machine-name"/>
            </td>
          </tr>
          <tr>
            <th>Date/time:</th>
            <td class="left">
              <xsl:value-of select="@date"/>
              <xsl:text> </xsl:text>
              <xsl:value-of select="@time"/>
            </td>
          </tr>
          <tr>
            <th>Duration:</th>
            <td class="left">
              <xsl:value-of select="test-suite/@time"/>
              <xsl:text> seconds</xsl:text>
            </td>
          </tr>
          <tr>
            <th>Culture:</th>
            <td class="left">
              <xsl:value-of select="culture-info/@current-culture"/>
            </td>
          </tr>
          <xsl:if test="not(culture-info/@current-culture = culture-info/@current-uiculture)">
            <tr>
              <th>UI culture:</th>
              <td class="left">
                <xsl:value-of select="culture-info/@current-uiculture"/>
              </td>
            </tr>
          </xsl:if>
        </table>
      </div>
    </div>

    <!-- Apply test-results transformation -->
    <xsl:apply-templates/>
  </xsl:template>

  <!-- Transformation of top-level test-suites which are the feature files -->
  <xsl:template match="/test-results/test-suite/results/test-suite">
    <hr/>
    <!-- File name/feature -->
    <h2><xsl:value-of select="@name"/></h2>

    <!-- Iterate over second-level test-suites which are the scenarios -->
    <xsl:for-each select="results/test-suite">
      <!-- Use HTML element details to make scenarios expandable and collapsable -->
      <details>
        <xsl:choose>
          <xsl:when test="count(node()//test-case[@result='Success']) > 0 and count(node()//test-case[@result='Success']) = count(node()//test-case)">
            <xsl:attribute name="class">success</xsl:attribute>
          </xsl:when>
          <xsl:when test="count(node()//test-case[@result='Failure']) > 0">
            <xsl:attribute name="class">failure</xsl:attribute>
            <xsl:attribute name="open">open</xsl:attribute>
          </xsl:when>
          <xsl:otherwise>
            <xsl:attribute name="class">inconclusive</xsl:attribute>
          </xsl:otherwise>
        </xsl:choose>
        <summary><strong><xsl:value-of select="@name"/></strong></summary>

        <!-- Iterate over test-cases which are the scenario steps -->
        <xsl:for-each select="results//test-case">
          <div>
            <xsl:choose>
              <xsl:when test="@result = 'Success'">
                <xsl:attribute name="class">success</xsl:attribute>
              </xsl:when>
              <xsl:when test="@result = 'Inconclusive'">
                <xsl:attribute name="class">inconclusive</xsl:attribute>
              </xsl:when>
              <xsl:otherwise>
                <xsl:attribute name="class">failure</xsl:attribute>
              </xsl:otherwise>
            </xsl:choose>
            <!-- The description of the test-case contains the complete step text -->
            <xsl:value-of select="@description"/>
          </div>
          <!-- Failure message will be displayed too -->
          <xsl:if test="failure/message">
            <pre class="failureMessage"><xsl:value-of select="failure/message"/></pre>
          </xsl:if>
          <!-- And inconclusive reasons -->
          <xsl:if test="reason/message">
            <pre class="inconclusiveMessage"><xsl:value-of select="reason/message"/></pre>
          </xsl:if>
        </xsl:for-each>
        </details>
      </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>