function Should-Any {
    <#
    .SYNOPSIS
    Compares all items in a collection to a filter script. If the filter returns true, or does not throw for any of the items in the collection, the assertion passes.

    .DESCRIPTION
    This assertion runs the filter script against each item until one passes. Nested Should-* failures are treated as filter failures and included in the reported reasons when nothing matches.

    An item passes when the filter returns a value that is true, or returns nothing at all and does not throw, which is what a filter that asserts on the item itself does. A lone value that is false fails the item whatever its type, so `{ 0 }` and `{ '' }` fail; `$null` passes, because PowerShell does not distinguish it from no output at all. A filter that returns several values is judged on the first one only when that is the boolean `$false`, so output from something the filter called does not decide the item. An empty filter is rejected, because it says nothing about any item and the first item would pass it.

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
    $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input -As 'CollectionItems'
    $Actual = $assert.Actual()

    if ($null -eq $Actual -or 0 -eq @($Actual).Count) {
        $assert.Fail("Expected at least one item in collection to pass filter <expected>, but <actualType> <actual> contains no items to compare.", @{ Expected = $Expected; Because = $Because })
    }

    # Is the filter empty? A scriptblock taken from a function, ${function:Test-Positive}, has a
    # FunctionDefinitionAst whose blocks live on .Body, and '{ process { ... } }' has no EndBlock at
    # all. $null.Count is 0 in PowerShell, so looking at EndBlock.Statements.Count alone called both
    # of those empty and rejected two working filter shapes. Reject only what is positively empty.
    $filterBody = $FilterScript.Ast
    if ($filterBody -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
        $filterBody = $filterBody.Body
    }

    $filterIsEmpty = $false
    if ($filterBody -is [System.Management.Automation.Language.ScriptBlockAst]) {
        $filterIsEmpty = $true
        foreach ($filterBlock in $filterBody.BeginBlock, $filterBody.ProcessBlock, $filterBody.EndBlock) {
            if ($null -ne $filterBlock -and 0 -lt $filterBlock.Statements.Count) {
                $filterIsEmpty = $false
                break
            }
        }
    }

    # An empty filter says nothing about any item, so the first item would pass it. An assertion
    # that cannot fail is worse than no assertion, because it reads like one (#3038).
    if ($filterIsEmpty) {
        $assert.Fail("Expected at least one item in collection <actual> to pass filter <expected>,<because> but the filter is empty, so it says nothing about them.", @{ Expected = $Expected; Because = $Because })
    }

    $failReasons = $null
    $appendMore = $false
    $anyPassed = $false
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

        # Did the filter say false? The boolean $false as the first output, which is what this has
        # always looked at, and also a lone value of another type that is false, which used to pass:
        # '1, 2, 3 | Should-All { 0 }' passed although 0 is false (#3038).
        #
        # $null stays a pass. The code this replaces said so on purpose, and PowerShell does not let
        # us tell '{ $null }' apart from a filter that returned nothing at all.
        #
        # A filter that returns more than one value is left alone, because the extra values are
        # usually output from something the filter called ('$list.Add($_); $true') and only the
        # predicate was meant.
        $saidFalse = ($pass.Count -ge 1) -and ($pass[0] -is [bool]) -and ($false -eq $pass[0])
        $saidFalseAsAnotherType = (1 -eq $pass.Count) -and ($null -ne $pass[0]) -and ($pass[0] -isnot [bool]) -and (-not $pass[0])
        if (-not ($saidFalse -or $saidFalseAsAnotherType)) {
            $anyPassed = $true
            break
        }
    }

    if (-not $anyPassed) {
        $Message = "Expected at least one item in collection <actual> to pass filter <expected>, but none of the items passed the filter."
        if ($null -ne $failReasons) {
            $failReasons = $failReasons -join "`n"
            if ($appendMore) {
                $failReasons += "`nand more..."
            }
            $Message += "`nReasons :`n$failReasons"
        }
        $assert.Fail($Message, @{ Expected = $Expected; Because = $Because })
    }
}
