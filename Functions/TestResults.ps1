$scriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
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
        failures = 0;        
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
    $report.Environment = (Get-RunTimeEnvironment)
    Invoke-Template 'TestResults.template.xml' $report | Set-Content $outputFile -force
}

function Get-TotalTestTime($tests) {
    $totalTime = 0;
    $tests | %{
        $totalTime += $_.time
    }
    return $totalTime;
}

function Get-Template($fileName) {
    $path = '.\templates'
    if($Global:ModulePath) {
        $path = $global:ModulePath + '\templates'
    }    
    return Get-Content ("$path\$filename")
}

function Get-TestResults($tests) {
    $testCaseXmls = $tests | %{ 
        $result = $_
        if($result.success) {
            Invoke-Template 'TestCaseSuccess.template.xml' $result
        }
        else {
            Invoke-Template  'TestCaseFailure.template.xml' $result
        }
    }
    return $testCaseXmls
}

function Get-RunTimeEnvironment() {
    $osSystemInformation = (Get-WmiObject -computer 'localhost' -cl Win32_OperatingSystem)
    $currentCulture = ([System.Threading.Thread]::CurrentThread.CurrentCulture).Name
    $data = @{
        osVersion = $osSystemInformation.Version
        platform = $osSystemInformation.Name
        runPath = (Get-Location).Path
        machineName = $env:ComputerName
        userName = $env:Username
        userDomain = $env:userDomain
        currentCulture = $currentCulture
    }
    return Invoke-Template 'TestEnvironment.template.xml' $data
}

function Get-ReplacementArgs($template, $data) {
   $replacements = ($data.keys | %{
            if($template -match "@@$_@@") {
                $value = $data.$_ -replace "``", "" -replace "`'", ""
                "-replace '@@$_@@', '$value'"
            }
        })
   return $replacements
}

function Invoke-Template($templatName, $data) {
    $template = Get-Template $templatName
    $replacments = Get-ReplacementArgs $template $data
    return Invoke-Expression "`$template $replacments"
}

function Exit-WithCode {
    $failedTestCount = $Global:TestResults.FailedTests.Length
    $host.SetShouldExit($failedTestCount)
}

