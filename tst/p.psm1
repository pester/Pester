$script:failed = 0
$script:total = 0


function ImportDir {
    [CmdletBinding()]
    param($Directory)

    $seessionState = $PSCmdlet.SessionState


    $sb = {
        param ($p)
        foreach ($f in @(Get-ChildItem $Directory -Recurse -Filter *.ps1 |
                    where { $_.FullName -notLike "*Tests.ps1" } |
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

    Write-Host # VSCode puts the first line to a weird place if we don't start with newline
    & $ScriptBlock

    $passed = $script:total - $script:failed
    Write-Host
    Write-Host -NoNewline "passed $($passed), " -ForegroundColor Black -BackgroundColor Green
    Write-Host -NoNewline "failed $($script:failed), " -ForegroundColor Black -BackgroundColor Red
    Write-Host "total $($script:total) " -ForegroundColor Black -BackgroundColor DarkGray

    if ($PassThru) {
        [PSCustomObject]@{
            Failed = $script:failed
            Total  = $script:total
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
            Write-Host "| - $Name " -ForegroundColor Black -BackgroundColor Cyan
            $null = & $ScriptBlock
        }
    }
}

function dt {
    param(
        [String] $Name,
        [ScriptBlock] $ScriptBlock
    )
    $ci = [Environment]::GetEnvironmentVariable("CI")
    if ($null -ne $ci -and "0" -ne $ci) {
        throw "dt was used in while running in CI environment, did you forget to remove it after debugging a test?"
    }
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
        if (-not $script:filter -or $script:filter -like "*$([System.Management.Automation.WildcardPattern]::Escape($name))") {
            try {
                $script:total++
                $null = & $ScriptBlock
                Write-Host "[y] - $Name " -ForegroundColor Black -BackgroundColor Green -NoNewline ; Write-Host
            }
            catch {
                $script:failed++
                function Get-FullStackTrace ($ErrorRecord) {
                    $_.ScriptStackTrace | Out-String | % { $_ -replace '\s*line\s+(\d+)', '$1' }
                }
                # verify throws Exception directly, so if the type is something
                # different then show me more info because it's likely a bug in my code
                # otherwise show the assertion message and stacktrace to keep the noise
                # on test failure low
                if ([Exception] -ne $_.Exception.GetType()) {
                    Write-Host "[n] ERROR: - $Name -> $($_| Out-String) "  -ForegroundColor Black -BackgroundColor Red
                    $(Get-FullStackTrace $_) -split [Environment]::NewLine | foreach {
                        Write-Host " " -NoNewline
                        Write-Host " $_ "  -NoNewline -ForegroundColor Black -BackgroundColor Red
                        Write-Host
                    }
                }
                else {
                    # print just the error and full stack trace with numbers fixed so I can jump to them
                    # in VSCode
                    $first = $true
                    "$_" -split "`n" | foreach {
                        $txt = if ($first) {
                            "[n] - $Name -> $($_.Trim()) "
                            $first = $false
                        }
                        else {
                            $_.Trim() + " "
                        }
                        Write-Host $txt  -NoNewline -ForegroundColor Black -BackgroundColor Red
                        Write-Host
                    }
                    $(Get-FullStackTrace $_) -split [Environment]::NewLine | foreach {
                        Write-Host "  " -NoNewline
                        Write-Host "$($_.Trim()) "  -NoNewline -ForegroundColor Black -BackgroundColor Red
                        Write-Host
                    }
                }
            }
        }
    }
}
