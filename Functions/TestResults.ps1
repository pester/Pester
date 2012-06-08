function Get-GlobalTestResults {
    if ($Global:TestResults -ne $null) {
        return $Global:TestResults
    }

    $testResults = @{}
    $testResults.Tests = @();
    $testResults.FailedTests = @();
    $testResults.TestCount = 0
    $testResults.TestDepth = 0
    $testResults.runDate =  (Get-Date -format "dd-mm-yyyy")
    $testResults.runTime =  (Get-Date -format "hh:mm:ss")

    $Global:TestResults = $testResults
    return $Global:TestResults
}

function Reset-GlobalTestResults {
    $global:TestResults = $null
}

function Write-TestReport {
    $results = $Global:TestResults
    Write-NunitTestReport $results
    Write-Host Tests completed
    Write-Host Passed: $($results.TestCount - $results.FailedTests.length) Failed: $($results.FailedTests.length)
}

function Write-NunitTestReport($results, $outputFile = "TestResults.xml") {
    $results.total = $results.Tests.length
    $results.failures = $results.FailedTests.length

    $thisScript = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent    
    $successemplate = Get-Content '$thisScript\..\templates\TestCaseSuccess.template.xml'
    $failureTemplate = Get-Content '$thisScript\..\templates\TestCaseFailure.template.xml'
    
    $testCaseXmls = $results.Tests | %{ 
        $result = $_
        $replace_args = ($result.keys | %{
            "-replace '@@$_@@', '$($result.$_)'"
        }) -join " "
        if($result.success) {
            $expr = "`$successemplate $replace_args"
        }
        else {
            $expr = "`$failureTemplate $replace_args"
        }
        
        iex $expr
    }

    $resultTemplate = (Get-Content '$thisScript\..\templates\TestResults.template.xml');
    $replacements = @("total", "failures", "rundate", "runtime")
    $replace_args = ($results.keys | ?{ $replacements -contains $_} | %{
        "-replace '@@$_@@', '$($results.$_)'"
    }) -join " "
    $replace_args += " -replace '@@results@@', '$testCaseXmls'"
    $expr = "`$resultTemplate $replace_args"    
    iex $expr  | Set-Content $outputFile -force
}

function Exit-WithCode {
    $failedTestCount = $Global:TestResults.FailedTests.Length
    $host.SetShouldExit($failedTestCount)
}

