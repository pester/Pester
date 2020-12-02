function Verify-NotNull {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual
    )
    PROCESS {
        if ($null -eq $Actual) {
            throw [Exception]"Expected not `$null but got `$null."
        }

        $Actual
    }
}
