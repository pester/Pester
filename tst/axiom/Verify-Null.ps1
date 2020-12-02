function Verify-Null {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual
    )
    END {
        if ($null -ne $Actual) {
            throw [Exception]"Expected `$null but got '$Actual'."
        }

        $Actual
    }
}
