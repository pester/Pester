function It($name, [ScriptBlock] $test) 
{
    $results = Get-GlobalTestResults
    $margin = " " * $results.TestDepth
    $error_margin = $margin * 2
    $results.TestCount += 1

    $output = " $margin$name"

    $start_line_position = $test.StartPosition.StartLine
    $test_file = $test.File
    $line_count = -1
    $failures = 0
    $test_result = $true

    foreach ( $line in $test.ToString().Split("`n;") ) {
        $line_count++
        $line=$line.trim()
        if($line){
            $test_result = Invoke-Expression $line
            if ($test_result -and $test_result.GetType().FullName -eq "PesterFailure") {
                $failures += 1
                $results.FailedTests += $name
                $output | Write-Host -ForegroundColor red
                Write-Host -ForegroundColor red $error_margin"Failure at line: $($start_line_position + $line_count) in  $test_file"
                Write-Host -ForegroundColor red $error_margin$error_margin$line
                $expected = $test_result.Expected
                $observed = $test_result.Observed
                Write-Host -ForegroundColor red $error_margin"Expected: $expected"
                Write-Host -ForegroundColor red $error_margin"But was : $observed"
            }
        }
    }
    
    if($failures -eq 0) {$output | Write-Host -ForegroundColor green;}
}
