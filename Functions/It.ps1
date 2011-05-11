function It($name, [ScriptBlock] $test) 
{
    $results = Get-GlobalTestResults
    $martin = " " * $results.TestDepth
    $results.TestCount += 1

    $output = " $margin$name"

    $test_result = & $test

    if ($test_result) {
        $output | Write-Host -ForegroundColor green
    } else {
        $results.FailedTests += $name
        $output | Write-Host -ForegroundColor red
    }
}
