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
        # different then chances are I made a mistake and I want more
        # information than just the assertion message
        if ([Exception] -ne $_.Exception.GetType()) {
            Write-Host "ERROR: - $Name -> $($_ | Format-List * -Force | Out-String)"  -ForegroundColor Red
        }
        else {
            Write-Host "[-] - $Name -> $_"  -ForegroundColor Red
        }
    }
}