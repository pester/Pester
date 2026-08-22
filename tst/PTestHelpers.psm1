function Invoke-InNewProcess ([ScriptBlock] $ScriptBlock) {
    # get the path of the currently loaded Pester to re-import it in the child process
    $pesterPath = Get-Module Pester | Select-Object -ExpandProperty Path
    $powershell = Get-Process -Id $pid | Select-Object -ExpandProperty Path
    # run any scriptblock in a separate process to be able to grab all the output
    # doesn't enforce Invoke-Pester usage so we can test other public functions directly
    $command = {
        param ($PesterPath, [ScriptBlock] $ScriptBlock)
        Import-Module $PesterPath

        # During a code coverage run (test.ps1 -CC) the parent process traces itself, but the code
        # that executes here in the child process is invisible to it. When the parent asks for it
        # (via PESTER_CC_CHILD_* env vars, which we inherit) we trace this child the same way and
        # dump the coordinates we hit, so the parent can merge them into the single coverage report.
        # Note: this scriptblock is stringified and passed to the child as -Command, and on Windows
        # PowerShell (legacy native argument passing) only the user ScriptBlock is quote-escaped
        # below, so keep this block free of double quotes to avoid mangling the child command line.
        # Coverage collection is best-effort: any failure here must fall back to a plain run so the
        # test behaves exactly as without coverage.
        $ccDir = $env:PESTER_CC_CHILD_OUTPUT
        $ccTarget = $env:PESTER_CC_CHILD_TARGET
        $ccTracer = $null
        $ccPatched = $false
        if ($ccDir -and $ccTarget) {
            try {
                $pesterModule = Get-Module Pester
                $enter = & $pesterModule { Get-Command Enter-CoverageAnalysis }
                $start = & $pesterModule { Get-Command Start-TraceScript }
                $bps = & $enter -CodeCoverage $ccTarget -UseBreakpoints $false
                $ccPatched, $ccTracer = & $start $bps
            }
            catch {
                $ccTracer = $null
            }
        }
        try {
            . $ScriptBlock
        }
        finally {
            if ($null -ne $ccTracer) {
                try {
                    $stop = & (Get-Module Pester) { Get-Command Stop-TraceScript }
                    & $stop -Patched $ccPatched
                    $hitLines = [System.Collections.Generic.List[string]]::new()
                    $tab = [char]9
                    foreach ($path in $ccTracer.Hits.Keys) {
                        $byKey = $ccTracer.Hits[$path]
                        foreach ($key in $byKey.Keys) {
                            foreach ($point in $byKey[$key]) {
                                if ($point.Hit) { $hitLines.Add($path + $tab + $key); break }
                            }
                        }
                    }
                    $outFile = Join-Path $ccDir ('child-' + [System.Guid]::NewGuid().ToString('n') + '.tsv')
                    [System.IO.File]::WriteAllLines($outFile, $hitLines)
                }
                catch {
                    # ignore, coverage from this child is simply skipped
                }
            }
        }
    }.ToString()

    if ($PSVersionTable.PSVersion -ge '7.3' -and $PSNativeCommandArgumentPassing -ne 'Legacy') {
        $cmd = "& { $command } -PesterPath ""$PesterPath"" -ScriptBlock { $ScriptBlock }"
    }
    else {
        $cmd = "& { $command } -PesterPath ""$PesterPath"" -ScriptBlock { $($ScriptBlock -replace '"','\"') }"
    }

    & $powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command $cmd
}

function Verify-PathEqual {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Mandatory = $true, Position = 0)]
        $Expected
    )

    if ([string]::IsNullOrEmpty($Expected)) {
        throw 'Expected is null or empty.'
    }

    if ([string]::IsNullOrEmpty($Actual)) {
        throw 'Actual is null or empty.'
    }

    $e = ($expected -replace '\\', '/').Trim('/')
    $a = ($actual -replace '\\', '/').Trim('/')

    if ($e -ne $a) {
        throw "Expected path '$e' to be equal to '$a'."
    }
}

function Verify-Property {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Mandatory = $true, Position = 0)]
        [String] $PropertyName,
        [Parameter(Position = 1)]
        $Value
    )

    if ($null -eq $PropertyName) {
        throw 'PropertyName value is $null.'
    }

    if ($null -eq $Actual) {
        throw 'Actual value is $null.'
    }

    if (-not $Actual.PSObject.Properties.Item($PropertyName)) {
        throw "Expected object to have property $PropertyName!"
    }

    if ($null -ne $Value -and $Value -ne $Actual.$PropertyName) {
        throw "Expected property $PropertyName to have value '$Value', but it was '$($Actual.$PropertyName)'!"
    }
}

function Verify-XmlTime {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowNull()]
        [Nullable[TimeSpan]]
        $Expected,
        [switch]$AsJUnitFormat
    )

    if ($null -eq $Expected) {
        throw [Exception]'Expected value is $null.'
    }

    if ($null -eq $Actual) {
        throw [Exception]'Actual value is $null.'
    }

    if ('0.0000' -eq $Actual) {
        # it is unlikely that anything takes less than
        # 0.0001 seconds (one tenth of a millisecond) so
        # throw when we see 0, because that probably means
        # we are not measuring at all
        throw [Exception]'Actual value is zero.'
    }

    # Consider using standardized time-format for JUnit and NUnit
    if ($AsJUnitFormat) {
        # using this over Math.Round because it will output all the numbers for 0.1
        $e = $Expected.TotalSeconds.ToString('0.000', [CultureInfo]::InvariantCulture)
    }
    else {
        $e = [string][Math]::Round($Expected.TotalSeconds, 4)
    }

    if ($e -ne $Actual) {
        $message = "Expected and actual values differ!`n" +
        "Expected: '$e' seconds (raw '$($Expected.TotalSeconds)' seconds)`n" +
        "Actual  : '$Actual' seconds"

        throw [Exception]$message
    }

    $Actual
}
