function Verify-True {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual
    )

    if (-not $Actual) {
        throw [Exception]"Expected `$true but got '$Actual'."
    }

    $Actual
}
