$scriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
function Get-GlobalTestResults {
    if ($pester.testResults -ne $null) {
        return $pester.testResults
    }

    $pester.testResults = @{}
    $pester.testResults.Describes = @();
    $pester.testResults.CurrentDescribe = @{ name = ''; Tests = @() }
    $pester.testResults.TestCount = 0
    $pester.testResults.FailedTestsCount = 0
    $pester.testResults.TestDepth = 0
    $pester.testResults.TotalTime = 0;

    return $pester.testResults
}

function Reset-GlobalTestResults {
    $pester.testResults = $null
}

function Write-TestReport {
    $results = $pester.testResults
    Write-Host "Tests completed in $(Get-HumanTime $results.TotalTime)"
    Write-Host "Passed: $($results.TestCount - $results.FailedTestsCount) Failed: $($results.FailedTestsCount)"
}

function Get-HumanTime($seconds) {
    if($seconds -gt 0.99) {
        $time = [math]::Round($seconds, 2)
        $unit = "s"
    }
    else {
        $time = [math]::Floor($seconds * 1000)
        $unit = "ms"
    }
    return "$time$unit"
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
    }

    $report.total = $results.TestCount
    $report.failures = $results.FailedTestsCount
    $report.TestSuites = (Get-TestSuites $results.Describes)
    $report.testCases = (Get-TestResults $results.Tests)
    $report.Environment = (Get-RunTimeEnvironment)
    Invoke-Template 'TestResults.template.xml' $report | Set-Content $outputFile -force
}

function Get-TestSuites($describes) {
    $testSuites = ( $describes | %{
        $suite = @{  
            resultMessage = "Failure"
            totalTime = "0.0"
            name = $_.name
        }
        $suite.testCases = (Get-TestResults $_.Tests)  
        $suite.totalTime = (Get-TestTime $_.Tests)
        $suite.success = (Get-TestSuccess $_.Tests)
        if($suite.success -eq "True") 
        {
            $suite.resultMessage = "Success" 
        }
        Invoke-Template 'TestSuite.template.xml' $suite
    })
    return $testSuites
}

function Get-TestTime($tests) {
    $totalTime = 0;
    $tests | %{
        $totalTime += $_.time
    }
    return $totalTime;
}

function Get-TestSuccess($tests) {
    $success = "True"
    $tests | %{
        if($_.success -eq $false) {
            $success = "False"
        }
    }
    return $success;
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
    $osSystemInformation = (Get-WmiObject Win32_OperatingSystem)
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



function Exit-WithCode {
    $failedTestsCount = $Pester.TestResults.FailedTestsCount
    $host.SetShouldExit($failedTestsCount)
}

