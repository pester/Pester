function Should-BeAfter {
    <#
    .SYNOPSIS
    Asserts that the provided [datetime] is after the expected [datetime].

    .PARAMETER Actual
    The actual [datetime] value.

    .PARAMETER Expected
    The expected [datetime] value.

    .PARAMETER Time
    The time to add or subtract from the current time. This parameter uses fluent time syntax e.g. 1minute.

    .PARAMETER Ago
    Indicates that the -Time should be subtracted from the current time.

    .PARAMETER FromNow
    Indicates that the -Time should be added to the current time.

    .PARAMETER Now
    Indicates that the current time should be used as the expected time.

    .PARAMETER Because
    The reason why the actual value should be after the expected value.

    .EXAMPLE
    ```powershell
    (Get-Date).AddDays(1) | Should-BeAfter (Get-Date)
    ```


    This assertion will pass, because the actual value is after the expected value.

    .EXAMPLE
    ```powershell
    (Get-Date).AddDays(-1) | Should-BeAfter (Get-Date)
    ```

    This assertion will fail, because the actual value is not after the expected value.

    .EXAMPLE
    ```powershell
    (Get-Date).AddDays(1) | Should-BeAfter 10minutes -FromNow
    ```

    This assertion will pass, because the actual value is after the expected value.

    .EXAMPLE
    ```powershell
    (Get-Date).AddDays(-1) | Should-BeAfter -Time 3days -Ago
    ```

    This assertion will pass, because the actual value is after the expected value.

    .NOTES
    The `Should-BeAfter` assertion is the opposite of the `Should-BeBefore` assertion.

    .LINK
    https://pester.dev/docs/commands/Should-BeAfter

    .LINK
    https://pester.dev/docs/assertions
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding(DefaultParameterSetName = "Now")]
    param (
        [Parameter(Position = 2, ValueFromPipeline = $true)]
        $Actual,

        [Parameter(Position = 0, ParameterSetName = "Now")]
        [switch] $Now,

        [Parameter(Position = 0, ParameterSetName = "Fluent")]
        $Time,

        [Parameter(Position = 1, ParameterSetName = "Fluent")]
        [switch] $Ago,

        [Parameter(Position = 1, ParameterSetName = "Fluent")]
        [switch] $FromNow,

        [Parameter(Position = 0, ParameterSetName = "Expected")]
        [DateTime] $Expected
    )

    # Now is just a syntax marker, we don't need to do anything with it.
    $Now = $Now

    $currentTime = [datetime]::UtcNow.ToLocalTime()
    if ($PSCmdlet.ParameterSetName -eq "Expected") {
        # do nothing we already have expected value
    }
    elseif ($PSCmdlet.ParameterSetName -eq "Now") {
        $Expected = $currentTime
    }
    else {
        if ($Ago -and $FromNow -or (-not $Ago -and -not $FromNow)) {
            throw "You must provide either -Ago or -FromNow switch, but not both or none."
        }

        if ($Ago) {
            $Expected = $currentTime - (Get-TimeSpanFromStringWithUnit -Value $Time)
        }
        else {
            $Expected = $currentTime + (Get-TimeSpanFromStringWithUnit -Value $Time)
        }
    }

    if ($Actual -le $Expected) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected the provided [datetime] to be after <expectedType> <expected>,<because> but it was before: <actual>"
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }
}
