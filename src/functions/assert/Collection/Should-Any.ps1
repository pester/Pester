function Should-Any {
    <#
    .SYNOPSIS
    Compares all items in a collection to a filter script. If the filter returns true, or does not throw for any of the items in the collection, the assertion passes.

    .DESCRIPTION
    This assertion runs the filter script against each item until one passes. Nested Should-* failures are treated as filter failures and included in the reported reasons when nothing matches.

    .PARAMETER FilterScript
    A script block that filters the input collection. The script block can use Should-* assertions or throw exceptions to indicate failure.

    .PARAMETER Actual
    A collection of items to filter.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    1, 2, 3 | Should-Any { $_ -gt 2 }
    1, 2, 3 | Should-Any { $_ | Should-BeGreaterThan 2 }
    ```

    This assertion will pass, because at least one item in the collection passed the filter. 3 is greater than 2.

    .EXAMPLE
    ```powershell
    1, 2, 3 | Should-Any { $_ -gt 4 }
    1, 2, 3 | Should-Any { $_ | Should-BeGreaterThan 4 }
    ```

    The assertions will fail because none of theitems in the array are greater than 4.

    .NOTES
    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

    .LINK
    https://pester.dev/docs/commands/Should-Any

    .LINK
    https://pester.dev/docs/assertions

    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, Position = 1)]
        $Actual,
        [Parameter(Position = 0, Mandatory)]
        [scriptblock]$FilterScript,
        [String]$Because
    )

    Assert-BoundScriptBlockInput -ScriptBlock $FilterScript

    $Expected = $FilterScript
    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput
    $Actual = $collectedInput.Actual

    # Captured up-front (cheap reference grabs); the diagnostic hint itself is only computed inside
    # a failure branch, via & $reportFailure, so there is no cost on the passing path.
    $pipelineBuffer = $local:Input
    $isPipelineInput = $collectedInput.IsPipelineInput
    $reportFailure = {
        param($Message)
        $hint = Get-AssertionGotcha -Cmdlet $PSCmdlet -Buffer $pipelineBuffer -CollectedActual $Actual -IsPipelineInput $isPipelineInput -Expecting CollectionItems
        if ($hint) { $Message = "$Message`n`nHint: $hint" }
        Invoke-AssertionFailed -Message $Message -CallerCmdlet $PSCmdlet
    }

    if ($null -eq $Actual -or 0 -eq @($Actual).Count) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected at least one item in collection to pass filter <expected>, but <actualType> <actual> contains no items to compare."
        & $reportFailure $Message
    }

    $failReasons = $null
    $appendMore = $false
    foreach ($item in $Actual) {
        $underscore = [PSVariable]::new('_', $item)
        try {
            $pass = $FilterScript.InvokeWithContext($null, $underscore, $null)
        }
        catch {
            if ($null -eq $failReasons) {
                $failReasons = [System.Collections.Generic.List[string]]::new(10)
            }
            if ($failReasons.Count -lt 10) {
                $failReasons.Add($_.Exception.InnerException.Message)
            }
            else {
                $appendMore = $true
            }

            # InvokeWithContext returns collection. This makes it easier to check the value if we throw and don't assign the value.
            $pass = @($false)
        }

        # The API returns a collection and user can return anything from their script
        # or there can be no output when assertion is used, so we are checking if the first item
        # in the output is a boolean $false. The scriptblock should not fail in $null for example,
        # hence the explicit type check
        if (-not (($pass.Count -ge 1) -and ($pass[0] -is [bool]) -and ($false -eq $pass[0]))) {
            $pass = $true
            break
        }
    }

    if (-not $pass) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected at least one item in collection <actual> to pass filter <expected>, but none of the items passed the filter."
        if ($null -ne $failReasons) {
            $failReasons = $failReasons -join "`n"
            if ($appendMore) {
                $failReasons += "`nand more..."
            }
            $Message += "`nReasons :`n$failReasons"
        }
        & $reportFailure $Message
    }
    Set-AssertionPassResult
}
