function Should-BeBefore {
    <#
    .SYNOPSIS
    Asserts that the provided [datetime] is before the expected [datetime].

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

    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

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

    $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
    $Actual = $assert.Actual()

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
        $failed = $Actual -ge $Expected
    }
    catch {
        $comparisonError = $_
    }
    if ($comparisonError -or $failed) {
        if ($comparisonError -and -not $assert.Hint()) { throw $comparisonError }
        $assert.Fail("Expected the provided [datetime] to be before <expectedType> <expected>,<because> but it was after: <actual>", @{ Expected = $Expected; Because = $Because })
    }
}
