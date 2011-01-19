function It($name, [ScriptBlock] $test) 
{
    $results = Get-GlobalTestResults
    $results.TestCount += 1

    Write-Host -fore DarkCyan $name -NoNewLine

    $test_result = & $test

    if ($test_result) {
        Write-Host -ForegroundColor green " Success"
    } else {
        $results.FailedTests += $name
        Write-Host -ForegroundColor red " Failure`n$($test.ToString())" 
    }
}

