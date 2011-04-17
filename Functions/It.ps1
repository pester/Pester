function It($name, [ScriptBlock] $test) 
{
    $results = Get-GlobalTestResults
    $results.TestCount += 1

    $test_result = & $test

    if ($test_result) {
        $name | Write-Host -ForegroundColor green
    } else {
        $results.FailedTests += $name
        $name | Write-Host -ForegroundColor red
    }
}

