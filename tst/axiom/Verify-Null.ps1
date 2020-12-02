function Verify-Null {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual
    )
    PROCESS {
        if ($null -ne $Actual) {
            throw [Exception]"Expected `$null but got '$Actual'."
        }

        $Actual
    }
}
