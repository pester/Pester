function It($name, [ScriptBlock] $test) 
{
    Write-Host -fore DarkCyan $name -NoNewLine

    $test_result = & $test

    if ($test_result) {
        Write-Host -ForegroundColor green " Success"
    } else {
        Write-Host -ForegroundColor red " Failure`n$($test.ToString())" 
    }
}

