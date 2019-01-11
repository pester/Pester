function Verify-False {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual
    )

    if ($Actual) {
        throw [Exception]"Expected `$false but got '$Actual'."
    }

    $Actual
}
