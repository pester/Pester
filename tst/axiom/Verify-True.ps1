function Verify-True {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual
    )
    END {
        if ($null -eq $Actual) {
            throw [Exception]"Expected `$true but got '`$null'."
        }

        if (-not $Actual) {
            throw [Exception]"Expected `$true but got '$Actual'."
        }

        $Actual
    }
}
