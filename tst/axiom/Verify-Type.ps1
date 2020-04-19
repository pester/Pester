function Verify-Type {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Mandatory = $true, Position = 0)]
        [Type]$Expected
    )

    if ($Actual -isnot $Expected) {
        $message = "Expected value to be of type $($Expected.FullName)"
        $Actual = "but got " + $(if ($null -eq $Actual) {
                "'<null>'"
            }
            else {
                "'$($Actual.GetType().FullName)'"
            })
        throw [Exception]"$message, $Actual"
    }

    $Actual
}
