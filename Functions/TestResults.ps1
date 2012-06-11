function Get-GlobalTestResults {
    if ($Global:TestResults -ne $null) {
        return $Global:TestResults
    }

    $testResults = @{}
    $testResults.Tests = @();
    $testResults.FailedTests = @();
    $testResults.TestCount = 0
    $testResults.TestDepth = 0


    $Global:TestResults = $testResults
    return $Global:TestResults
}

function Reset-GlobalTestResults {
    $global:TestResults = $null
}

function Write-TestReport {
    $results = $Global:TestResults
    Write-Host Tests completed
    Write-Host Passed: $($results.TestCount - $results.FailedTests.length) Failed: $($results.FailedTests.length)
}

function Write-NunitTestReport($results, $outputFile) {
    if($results -eq $null) {
        return;
    }
    $report = @{
        runDate = (Get-Date -format "yyyy-MM-dd")
        runTime = (Get-Date -format "HH:mm:ss")
        total = 0;
        failuers = 0;        
        success = "True"
        resultMessage = "Success"
        totalTime = "0.0"
    }

    $report.total = $results.Tests.length
    if($results.FailedTests) {
        $report.failures = $results.FailedTests.length
        $report.success = "False"
        $report.resultMessage = "Failure"
    }
    $report.testCases = (Get-TestResults $results.Tests)  
    $report.totalTime = (Get-TotalTestTime $results.Tests)

    $resultTemplate = (Get-Content 'templates\TestResults.template.xml');
    $xmlResult = Invoke-Template $resultTemplate $report
    $xmlResult | Set-Content $outputFile -force
}

function Get-TotalTestTime($tests) {
    $totalTime = 0;
    $tests | %{
        $totalTime += $_.time
    }
    return $totalTime;
}

function Get-TestResults($tests) {
    $successemplate = Get-Content 'templates\TestCaseSuccess.template.xml'
    $failureTemplate = Get-Content 'templates\TestCaseFailure.template.xml'
    $testCaseXmls = $tests | %{ 
        $result = $_
        if($result.success) {
            Invoke-Template $successemplate $result
        }
        else {
            Invoke-Template $failureTemplate $result
        }
    }
    return $testCaseXmls
}

function Get-ReplacementArgs($template, $data) {
   $replacements = ($data.keys | %{
            if($template -match "@@$_@@") {
                "-replace '@@$_@@', '$($data.$_)'"
            }
        })
   $replacements -join " "
   return $replacements
}

function Invoke-Template($template, $data) {
    $replacments = Get-ReplacementArgs $template $data
    return Invoke-Expression "`$template $replacments"
}

function Exit-WithCode {
    $failedTestCount = $Global:TestResults.FailedTests.Length
    $host.SetShouldExit($failedTestCount)
}

