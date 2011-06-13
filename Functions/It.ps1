function It($name, [ScriptBlock] $test) 
{
    $results = Get-GlobalTestResults
    $margin = " " * $results.TestDepth
    $error_margin = $margin * 2
    $results.TestCount += 1

    $output = " $margin$name"

    $test_file = $test.File
    $failures = 0 
    $test_result = $true

    Start-PesterConsoleTranscript

    $test_result = & $test

    if ($test_result -and $test_result.GetType().FullName -eq "PesterFailure") {
        $failures += 1
        $results.FailedTests += $name
        $output | Write-Host -ForegroundColor red
        Write-Host -ForegroundColor red $error_margin"Failure at $name in $test_file"
        $expected = $test_result.Expected
        $observed = $test_result.Observed
        Write-Host -ForegroundColor red $error_margin"Expected: $expected"
        Write-Host -ForegroundColor red $error_margin"But was : $observed"
    }

    Stop-PesterConsoleTranscript

    if($failures -eq 0) {$output | Write-Host -ForegroundColor green;}
}

function Start-PesterConsoleTranscript {
    if (-not (Test-Path $TestDrive\transcripts)) {
        md $TestDrive\transcripts | Out-Null
    }
    Start-Transcript -Path "$TestDrive\transcripts\console.out" | Out-Null
}

function Stop-PesterConsoleTranscript {
    Stop-Transcript | Out-Null
}

function Get-ConsoleText {
    return (Get-Content "$TestDrive\transcripts\console.out")
}
