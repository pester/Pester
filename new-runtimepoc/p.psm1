$script:failed = 0
$script:total = 0
function i  {
    param(
        [ScriptBlock] $ScriptBlock,
        [Switch] $EnableExit
    )
    $script:failed = 0
    $script:total = 0
    $passed = $script:total - $script:failed
    & $ScriptBlock
    Write-Host -NoNewline "`npassed $($passed), " -ForegroundColor Green
    Write-Host -NoNewline "failed $($script:failed), " -ForegroundColor Red
    Write-Host "total $($script:total)" -ForegroundColor Gray

    if ($EnableExit -and $script:failed -gt 0) {
        exit ($script:failed)
    }
}
function b {
    param(
        [String] $Name,
        [ScriptBlock] $ScriptBlock
    )

    Write-Host "| - $Name" -ForegroundColor Cyan
    $null = & $ScriptBlock
}

function t {
    param(
        [String] $Name,
        [ScriptBlock] $ScriptBlock
    )

    try {
        $script:total++
        $null  = & $ScriptBlock
        Write-Host "[+] - $Name" -ForegroundColor Green
    }
    catch {
        $script:failed++
        function Get-FullStackTrace ($ErrorRecord) { 
            $_.ScriptStackTrace | Out-String | % { $_ -replace '\s*line\s+(\d+)','$1'}
        }
        # verify throws Exception directly, so if the type is someting
        # different then show me more info because it's likely a bug in my code
        # otherwise show the assertion message and stacktrace to keep the noise 
        # on test failure low
        if ([Exception] -ne $_.Exception.GetType()) {
            Write-Host "ERROR: - $Name -> $($_| Out-String)`n$(Get-FullStackTrace $_)"  -ForegroundColor Red
        }
        else {
            # print just the error and full stack trace with numbers fixed so I can jump to them
            # in VSCode
            Write-Host "[-] - $Name -> $($_)`n$(Get-FullStackTrace $_)"  -ForegroundColor Red
        }
    }
}