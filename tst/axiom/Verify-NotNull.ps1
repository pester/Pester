function Verify-NotNull {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual
    )
    END {
        if ($null -eq $Actual) {
            throw [Exception]"Expected not `$null but got `$null."
        }

        $Actual
    }
}
