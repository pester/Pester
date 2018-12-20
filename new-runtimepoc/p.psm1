function b {
    param(
        [String] $Name,
        [ScriptBlock] $ScriptBlock
    )

    Write-Host "| - $Name" -ForegroundColor Cyan
    & $ScriptBlock
}

function t {
    param(
        [String] $Name,
        [ScriptBlock] $ScriptBlock
    )

    try {
        & $ScriptBlock
        Write-Host "[+] - $Name" -ForegroundColor Green
    }
    catch {
        # verify throws Exeption directly, so if the type is someting
        # differnt then chances are I made a mistake and I want more information
        # than just the assertion message
        if ([Exception] -ne $_.Exception.GetType()) {
            Write-Host "ERROR: - $Name -> $($_ | Format-List * -Force | Out-String)"  -ForegroundColor Red
        }
        else {
            Write-Host "[-] - $Name -> $_"  -ForegroundColor Red
        }
    }
}