function Export-HtmlReport {
    param (
        [parameter(Mandatory = $true)]
        $TestReport,

        [parameter(Mandatory = $true)]
        [String]$Path
    )
    Write-HtmlReport $TestReport | Out-File $Path
}

function Get-EncodedText([string] $Text) {
    [System.Security.SecurityElement]::Escape($Text)
}

function Write-HtmlReport($TestReport) {
    @"
<!DOCTYPE html>
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
      details.stacktrace { font-size:8pt; margin:0pt; padding:0pt 0pt 5pt 0pt; }
      .stacktrace { font-size:8pt; }
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
"@
    Write-HtmlSummary $TestReport
    if ($TestReport.TestResult) {
        Write-HtmlResults ($TestReport.TestResult) 0
    }
    @"
  </body>
</html>
"@
}

function Write-HtmlSummary($TestReport) {
    if ($PSVersionTable.Keys -contains "PSEdition") {
        $extraVersionString = " ($($PSVersionTable.PSEdition))"
    }
    else {
        $extraVersionString = ""
    }
    $powerShellVersion = "$($PSVersionTable.PSVersion)$extraVersionString"
    if (-not $TestReport.Gherkin) {
        $testRunTitle = "Pester Spec Run"
        $mainGroupName = "Files"
        $subGroupName = "Groups"
        $testCasesName = "Specs"
    }
    else {
        $testRunTitle = "Pester Gherkin Run"
        $mainGroupName = "Features"
        $subGroupName = "Scenarios"
        $testCasesName = "Steps"
    }
    $operatingSystem = Get-EncodedText ((, ($TestReport.Environment.Platform) -split '\|')[0])
    $osVersion = Get-EncodedText $TestReport.Environment.'os-version'
    $user = Get-EncodedText $TestReport.Environment.'user'
    $hostname = Get-EncodedText $TestReport.Environment.'machine-name'
    $date = $TestReport.Date
    $time = $TestReport.Time
    $duration = Get-EncodedText "$($TestReport.Duration) seconds"
    $culture = $TestReport.Culture
    $uiCulture = $TestReport.UiCulture
    @"
    <div id="overview">
      <div id="results">
        <h1>$testRunTitle</h1>
        <table>
          <tr>
            <td class="widthHeader2">&#160;</td>
            <th class="widthHeader">Total</th>
            <th class="success widthHeader">Passed</th>
"@
    # TODO Use term 'Inconclusive' instead of 'Skipped' in the summary
    #      Currently 'Skipped' is chosen since 'Inconclusive' is long and makes the table ugly
    @"
            <th class="inconclusive widthHeader">Skipped</th>
            <th class="failure widthHeader">Failed</th>
          </tr>
          <tr>
            <th class="left">$($mainGroupName):</th>
            <td>$($TestReport.MainGroupResult.TotalCount)</td>
            <td class="success">$($TestReport.MainGroupResult.PassedCount)</td>
            <td class="inconclusive">$($TestReport.MainGroupResult.InconclusiveCount)</td>
            <td class="failure">$($TestReport.MainGroupResult.FailedCount)</td>
          </tr>
          <tr>
            <th class="left">$($subGroupName):</th>
            <td>$($TestReport.SubGroupResult.TotalCount)</td>
            <td class="success">$($TestReport.SubGroupResult.PassedCount)</td>
            <td class="inconclusive">$($TestReport.SubGroupResult.InconclusiveCount)</td>
            <td class="failure">$($TestReport.SubGroupResult.FailedCount)</td>
          </tr>
          <tr>
            <th class="left">$($testCasesName):</th>
            <td>$($TestReport.TestResult.TotalCount)</td>
            <td class="success">$($TestReport.TestResult.PassedCount)</td>
            <td class="inconclusive">$($TestReport.TestResult.InconclusiveCount)</td>
            <td class="failure">$($TestReport.TestResult.FailedCount)</td>
          </tr>
        </table>
      </div>
      <div id="summary">
        <table>
"@
    if ($powerShellVersion) {
        @"
          <tr>
            <th>PowerShell version:</th>
            <td class="left">$powerShellVersion</td>
          </tr>
"@
    }
    @"
          <tr>
            <th>Operating system:</th>
            <td class="left">$operatingSystem</td>
          </tr>
          <tr>
            <th>Version:</th>
            <td class="left">$osVersion</td>
          </tr>
          <tr>
            <th>User:</th>
            <td class="left">$user@$hostName</td>
          </tr>
          <tr>
            <th>Date/time:</th>
            <td class="left">$date $time</td>
          </tr>
          <tr>
            <th>Duration:</th>
            <td class="left">$duration</td>
          </tr>
          <tr>
            <th>Culture:</th>
            <td class="left">$culture</td>
          </tr>
"@
    if ($culture -ne $uiCulture) {
        @"
            <tr>
              <th>UI culture:</th>
              <td class="left">$uiCulture</td>
            </tr>
"@
    }
    @"
        </table>
      </div>
    </div>
"@
}

function Write-HtmlResults($TestResult, $Level) {
    if ($Level -eq 1) {
        @"
    <hr />
    <h2>$(Get-EncodedText $TestResult.Name)</h2>
"@
    }
    elseif ($Level -ge 2) {
        $open = ''
        if ($TestResult.PassedCount -gt 0 -and $TestResult.PassedCount -eq $TestResult.TotalCount) {
            $testSuiteCssClass = 'success'
        }
        elseif ($TestResult.FailedCount -gt 0) {
            $testSuiteCssClass = 'failure'
            $open = ' open="open"'
        }
        else {
            $testSuiteCssClass = 'inconclusive'
        }
        @"
    <details class="$testSuiteCssClass"$open>
      <summary>
        <strong>$(Get-EncodedText $TestResult.Name)</strong>
      </summary>
"@
    }
    foreach ($child in $TestResult.Children) {
        if (-not $child.IsTestCase) {
            Write-HtmlResults $child ($Level + 1)
        }
        else {
            Write-HtmlTestCase $child
        }
    }
    if ($Level -eq 1) {
    }
    elseif ($Level -ge 2) {
        @"
    </details>
"@
    }
}

function Write-HtmlTestCase($TestResult) {
    $showStackTrace = $false
    switch ($TestResult.Outcome) {
        'Passed' {
            $testCaseCssClass = 'success'
            $failureMessageClass = ''
        }
        'Inconclusive' {
            $testCaseCssClass = 'inconclusive'
            $failureMessageClass = 'inconclusiveMessage'
        }
        default {
            $testCaseCssClass = 'failure'
            $failureMessageClass = 'failureMessage'
            $showStackTrace = $true
        }
    }
    @"
      <div class="$testCaseCssClass">$(Get-EncodedText $TestResult.Name)</div>
"@
    if ($TestResult.FailureMessage) {
        @"
      <pre class="$failureMessageClass">$(Get-EncodedText $TestResult.FailureMessage)</pre>
"@
        if ($showStackTrace) {
            @"
      <details class="stacktrace">
          <summary>Error details</summary>
          <pre class="$failureMessageClass stacktrace">$(Get-EncodedText $TestResult.StackTrace)</pre>
      </details>
"@
        }
    }
}
