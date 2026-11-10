function Should-All {
    <#
    .SYNOPSIS
    Compares all items in a collection to a filter script. If the filter returns true, or does not throw for all the items in the collection, the assertion passes.

    .DESCRIPTION
    This assertion runs the filter script against every item in the collection. Nested Should-* failures are treated as filter failures and included in the reported reasons.

    An item passes when the filter returns a value that is true, or returns nothing at all and does not throw, which is what a filter that asserts on the item itself does. A value that is false fails the item whatever its type, so `{ 0 }` and `{ '' }` fail. An empty filter is rejected, because it says nothing about any item and every item would pass it.

    .PARAMETER FilterScript
    A script block that filters the input collection. The script block can use Should-* assertions or throw exceptions to indicate failure.

    .PARAMETER Actual
    A collection of items to filter.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    1, 2, 3 | Should-All { $_ -gt 0 }
    1, 2, 3 | Should-All { $_ | Should-BeGreaterThan 0 }
    ```

    This assertion will pass, because all items pass the filter.

    .EXAMPLE
    ```powershell
    1, 2, 3 | Should-All { $_ -gt 1 }
    1, 2, 3 | Should-All { $_ | Should-BeGreaterThan 1 }
    ```

    The assertions will fail because not all items in the array are greater than 1.

    .NOTES
    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

    .LINK
    https://pester.dev/docs/commands/Should-All

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
        $assert.Fail("Expected all items in collection to pass filter <expected>, but <actualType> <actual> contains no items to compare.", @{ Expected = $Expected; Because = $Because })
    }

    # An empty filter says nothing about any item, so every item would pass it. An assertion that
    # cannot fail is worse than no assertion, because it reads like one (#3038).
    if (0 -eq $FilterScript.Ast.EndBlock.Statements.Count) {
        $assert.Fail("Expected all items in collection <actual> to pass filter <expected>,<because> but the filter is empty, so it says nothing about them.", @{ Expected = $Expected; Because = $Because })
    }

    $failReasons = $null
    $appendMore = $false
    # we are jumping between modules so I need to explicitly pass the _ variable
    # simply using '&' won't work
    # see: https://blogs.msdn.microsoft.com/sergey_babkins_blog/2014/10/30/calling-the-script-blocks-in-powershell/
    $actualFiltered = foreach ($item in $Actual) {
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

            $pass = @($false)
        }

        # The filter either returns something, which has to be true for the item to pass, or
        # returns nothing because it asserted on the item itself and did not throw. No output is a
        # pass; output is judged on whether it is true.
        #
        # It used to be a failure only when the output was exactly the boolean $false, so a filter
        # that returned a falsy value of another type passed: '1, 2, 3 | Should-All { 0 }' passed
        # although 0 is false (#3038).
        if (($pass.Count -ge 1) -and (-not $pass[0])) {
            $item
        }
    }

    # Make sure are checking the count of the filtered items, not just truthiness of a single item.
    $actualFiltered = @($actualFiltered)
    if (0 -lt $actualFiltered.Count) {
        $data = @{
            actualFiltered      = if (1 -eq $actualFiltered.Count) { $actualFiltered[0] } else { $actualFiltered }
            actualFilteredCount = $actualFiltered.Count
            Expected            = $Expected
            Because             = $Because
        }

        $Message = "Expected all items in collection <actual> to pass filter <expected>, but <actualFilteredCount> of them <actualFiltered> did not pass the filter."
        if ($null -ne $failReasons) {
            $failReasons = $failReasons -join "`n"
            if ($appendMore) {
                $failReasons += "`nand more..."
            }
            $Message += "`nReasons :`n$failReasons"
        }
        $assert.Fail($Message, $data)
    }
}
