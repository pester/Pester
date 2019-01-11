function Verify-Equal {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Mandatory = $true, Position = 0)]
        $Expected
    )

    if ($Expected -ne $Actual) {
        $message = "Expected and actual values differ!`n" +
        "Expected: '$Expected'`n" +
        "Actual  : '$Actual'"
        if ($Expected -is [string] -and $Actual -is [string]) {
            $message += "`nExpected length: $($Expected.Length)`nActual length: $($Actual.Length)"
        }
        throw [Exception]$message
    }

    $Actual
}
