$script:failed = 0
$script:total = 0

function ImportDir {
    [CmdletBinding()]
    param($Directory)

    $seessionState = $PSCmdlet.SessionState


    $sb = {
        param ($p)
        foreach ($f in @(Get-ChildItem $Directory -Recurse -Filter *.ps1 |
                    where { $_.FullName -notLike "*Tests.ps1"} |
                    select -ExpandProperty FullName)) {
            . $f
        }
        Remove-Variable -Scope Local -Name p, f
    }

    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
    $SessionStateInternal = $SessionState.GetType().GetProperty('Internal', $flags).GetValue($SessionState, $null)
    $sb.GetType().GetProperty('SessionStateInternal', $flags).SetValue($sb, $SessionStateInternal, $null)
    . $sb $Dependency
}


function i {
    param(
        [ScriptBlock] $ScriptBlock,
        [Switch] $EnableExit,
        [Switch] $PassThru
    )

    $script:discovery = $true
    $script:filter = $null
    & $ScriptBlock

    $script:discovery = $false
    $script:failed = 0
    $script:total = 0

    & $ScriptBlock

    $passed = $script:total - $script:failed
    Write-Host -NoNewline "`npassed $($passed), " -ForegroundColor Green
    Write-Host -NoNewline "failed $($script:failed), " -ForegroundColor Red
    Write-Host "total $($script:total)" -ForegroundColor Gray

    if ($PassThru) {
        [PSCustomObject]@{
            Failed = $script:failed
            Total = $script:total
        }
    }

    if ($EnableExit -and $script:failed -gt 0) {
        exit ($script:failed)
    }
}

function b {
    param(
        [String] $Name,
        [ScriptBlock] $ScriptBlock
    )

    $script:path = $name

    if ($script:discovery) {
        $null = & $ScriptBlock

    }
    else {
        if (-not $script:filter -or $script:filter -like "$name*") {
            Write-Host "| - $Name" -ForegroundColor Cyan
            $null = & $ScriptBlock
        }
    }
}

function dt {
    param(
        [String] $Name,
        [ScriptBlock] $ScriptBlock
    )
    $f = "$script:path.$Name"

    $script:filter = $f

    t $Name $ScriptBlock
}
function t {
    param(
        [String] $Name,
        [ScriptBlock] $ScriptBlock
    )

    if (-not $script:discovery) {
        if (-not $script:filter -or $script:filter -like "*$name") {
            try {
                $script:total++
                $null = & $ScriptBlock
                Write-Host "[+] - $Name" -ForegroundColor Green
            }
            catch {
                $script:failed++
                function Get-FullStackTrace ($ErrorRecord) {
                    $_.ScriptStackTrace | Out-String | % { $_ -replace '\s*line\s+(\d+)', '$1'}
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
    }
}
