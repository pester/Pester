function Should-BeAfter {
    <#
    .SYNOPSIS
    Asserts that the provided [datetime] is after the expected [datetime].

    .DESCRIPTION
    This assertion accepts either an expected `[datetime]` or a fluent relative time expression. Use `-Now`, `-Ago`, or `-FromNow` to compare against the current local time.

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

    # A relational operator throws a native conversion error when $Actual is not a comparable single
    # value, which is what happens when a multi-item collection is piped in and unwrapped to [object[]].
    # Catch it so we can show the input hint instead of a cryptic "Could not compare" error; when it is
    # not a piped-collection gotcha we have nothing to add, so the original error is rethrown.
    $failed = $false
    $comparisonError = $null
    try {
        $failed = $Actual -le $Expected
    }
    catch {
        $comparisonError = $_
    }
    if ($comparisonError -or $failed) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected the provided [datetime] to be after <expectedType> <expected>,<because> but it was before: <actual>"
        $hint = Get-AssertionGotcha -Cmdlet $PSCmdlet -Buffer $local:Input -CollectedActual $Actual -IsPipelineInput $collectedInput.IsPipelineInput -Expecting Scalar
        if ($comparisonError -and -not $hint) { throw $comparisonError }
        if ($hint) { $Message = "$Message`n`nHint: $hint" }
        Invoke-AssertionFailed -Message $Message -CallerCmdlet $PSCmdlet
    }
    Set-AssertionPassResult
}
