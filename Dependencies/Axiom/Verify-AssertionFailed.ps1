function Verify-AssertionFailed {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ScriptBlock]$ScriptBlock
    )

    $assertionResult = $null
    try {
        $assertionResult = & $ScriptBlock
    }
    catch [Exception] {
        $assertionResult = $_
    }

    $assertionResult

    if ($assertionResult -isnot [System.Management.Automation.ErrorRecord]) {
        $result = if ($null -eq $assertionResult) {
            "no assertion failure error was thrown!"
        }
        else {
            "other error was thrown! $($assertionResult | Format-List -Force * | Out-String)"
        }
        throw [Exception]"Expected the script block { $ScriptBlock } to fail in Pester assertion, but $result"
    }
}
