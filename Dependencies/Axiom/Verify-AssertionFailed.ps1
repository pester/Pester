function Verify-AssertionFailed {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ScriptBlock]$ScriptBlock
    )

    $assertionExceptionThrown = $false
    $err = $null

    try {
        $null = & $ScriptBlock
    }
    catch [Exception] {
        $assertionExceptionThrown = ($_.FullyQualifiedErrorId -eq 'PesterAssertionFailed')
        $err = $_
        Write-Output $err
    }

    $test = & (Get-Module Pester) {
        Get-CurrentTest
    }

    if (-not $assertionExceptionThrown -and $test.ErrorRecord.Count -gt 0) {
        $pesterAssertionErrors = foreach ($record in $test.ErrorRecord) {
            if ($record.FullyQualifiedErrorId -eq 'PesterAssertionFailed') {
                $record
            }
        }

        $assertionExceptionThrown = $null -ne $pesterAssertionErrors
        Write-Output $test.ErrorRecord
    }

    $test.ErrorRecord.Clear()

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
