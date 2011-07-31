function Get-GlobalTestResults {
    if ($Global:TestResults -ne $null) {
        return $Global:TestResults
    }

    $testResults = @{}
    $testResults.FailedTests = @()
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

function Exit-WithCode {
    $failedTestCount = $Global:TestResults.FailedTests.Length
    $Global:TestResults = $null

    #$host.SetShouldExit($failedTestCount)
    exit $failedTestCount
}

