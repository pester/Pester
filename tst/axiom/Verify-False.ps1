function Verify-False {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual
    )
    END {
        if ($null -eq $Actual) {
            throw [Exception]"Expected `$false but got '`$null'."
        }

        if ($Actual) {
            throw [Exception]"Expected `$false but got '$Actual'."
        }

        $Actual
    }
}
