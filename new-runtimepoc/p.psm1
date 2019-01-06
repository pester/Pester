$script:failed = 0
$script:total = 0
function i  {
    param(
        [ScriptBlock] $ScriptBlock
    )
    $script:failed = 0
    $script:total = 0
    & $ScriptBlock
    Write-Host -NoNewline "`npassed $($total-$failed), " -ForegroundColor Green
    Write-Host -NoNewline "failed $($failed), " -ForegroundColor Red
    Write-Host "total $($total)" -ForegroundColor Gray
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
        # verify throws Exception directly, so if the type is someting
        # different then chances are I made a mistake and I want to see more
        # information than just the assertion message
        if ([Exception] -ne $_.Exception.GetType()) {
            Write-Host "ERROR: - $Name -> $($_| Out-String)"  -ForegroundColor Red
        }
        else {
            # print just the error and full stack trace with numbers fixed so I can jump to them
            # in VSCode
            Write-Host "[-] - $Name -> $($_)`n$($_.ScriptStackTrace | Out-String | % { $_ -replace '\s*line\s+(\d+)','$1'})"  -ForegroundColor Red
        }
    }
}