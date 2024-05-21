
function Verify-Like {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Mandatory = $true, Position = 0)]
        $Expected
    )

    if ($Actual -notlike $Expected) {
        $message = "Expected is not present in Actual!`n" +
        "Expected: '$Expected'`n" +
        "Actual  : '$Actual'"

        throw [Exception]$message
    }

    $Actual
}
