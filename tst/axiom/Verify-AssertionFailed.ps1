function Verify-AssertionFailed {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("Pester.BuildAnalyzerRules\Measure-SafeCommands", "")]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ScriptBlock]$ScriptBlock
    )
    END {
        $assertionExceptionThrown = $false
        $err = $null

        try {
            $null = & $ScriptBlock
        }
        catch [Exception] {
            $assertionExceptionThrown = ($_.FullyQualifiedErrorId -eq 'PesterAssertionFailed')
            $err = $_
            $err
        }

        if (-not $assertionExceptionThrown) {
            $result = if ($null -eq $err) {
                "no assertion failure error was thrown!"
            }
            else {
                "other error was thrown! $($err | Format-List -Force * | Out-String)"
            }
            throw [Exception]"Expected the script block { $ScriptBlock } to fail in Pester assertion, but $result"
        }
    }
}
