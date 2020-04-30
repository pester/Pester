function Verify-Same {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Mandatory = $true, Position = 0)]
        $Expected
    )

    if (-not [object]::ReferenceEquals($Expected, $Actual)) {
        throw [Exception]"Expected the objects to be the same instance but they were not."
    }

    $Actual
}
