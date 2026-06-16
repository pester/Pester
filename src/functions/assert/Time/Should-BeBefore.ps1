function Should-BeBefore {
    <#
    .SYNOPSIS
    Asserts that the provided [datetime] is before the expected [datetime].

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
    The reason why the actual value should be before the expected value.

    .EXAMPLE
    ```powershell
    (Get-Date).AddDays(-1) | Should-BeBefore (Get-Date)
    ```

    This assertion will pass, because the actual value is before the expected value.

    .EXAMPLE
    ```powershell
    (Get-Date).AddDays(1) | Should-BeBefore (Get-Date)
    ```

    This assertion will fail, because the actual value is not before the expected value.

    .EXAMPLE
    ```powershell
    (Get-Date).AddMinutes(1) | Should-BeBefore 10minutes -FromNow
    ```

    This assertion will pass, because the actual value is before the expected value.

    .EXAMPLE
    ```powershell
    (Get-Date).AddDays(-2) | Should-BeBefore -Time 3days -Ago
    ```

    This assertion will pass, because the actual value is before the expected value.

    .NOTES
    The `Should-BeBefore` assertion is the opposite of the `Should-BeAfter` assertion.

    .LINK
    https://pester.dev/docs/commands/Should-BeBefore

    .LINK
    https://pester.dev/docs/assertions
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding(DefaultParameterSetName = "Now")]
    param (
        [Parameter(Position = 2, ValueFromPipeline = $true)]
        $Actual,

        [Parameter(ParameterSetName = "Now")]
        [switch] $Now,

        [Parameter(Position = 0, ParameterSetName = "FluentAgo")]
        [Parameter(Position = 0, ParameterSetName = "FluentFromNow")]
        [String] $Time,

        [Parameter(Mandatory, ParameterSetName = "FluentAgo")]
        [switch] $Ago,

        [Parameter(Mandatory, ParameterSetName = "FluentFromNow")]
        [switch] $FromNow,

        [Parameter(Position = 0, ParameterSetName = "Expected")]
        [DateTime] $Expected,

        [String] $Because
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual

    # Now is just a syntax marker, we don't need to do anything with it.
    $Now = $Now

    $currentTime = [datetime]::UtcNow.ToLocalTime()
    switch ($PSCmdlet.ParameterSetName) {
        "Expected" {
            # do nothing we already have expected value
        }
        "Now" {
            $Expected = $currentTime
        }
        "FluentAgo" {
            $Expected = $currentTime - (Get-TimeSpanFromStringWithUnit -Value $Time)
        }
        "FluentFromNow" {
            $Expected = $currentTime + (Get-TimeSpanFromStringWithUnit -Value $Time)
        }
    }

    if ($Actual -ge $Expected) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected the provided [datetime] to be before <expectedType> <expected>,<because> but it was after: <actual>"
        throw (New-ShouldErrorRecord -Message $Message -Invocation $MyInvocation)
    }
    Set-AssertionPassResult
}
