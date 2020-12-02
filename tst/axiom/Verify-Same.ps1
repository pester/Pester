function Verify-Same {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Mandatory = $true, Position = 0)]
        $Expected
    )
    END {
        if (-not [object]::ReferenceEquals($Expected, $Actual)) {
            throw [Exception]"Expected the objects to be the same instance but they were not."
        }

        $Actual
    }
}
