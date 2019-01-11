function Verify-NotSame {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Mandatory = $true, Position = 0)]
        $Expected
    )

    if ([object]::ReferenceEquals($Expected, $Actual)) {
        throw [Exception]"Expected the objects to be different instance but they were the same instance."
    }

    $Actual
}
