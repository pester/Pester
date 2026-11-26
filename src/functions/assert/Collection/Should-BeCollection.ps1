function Should-BeCollection {
    <#
    .SYNOPSIS
    Compares collections for equality, by comparing their sizes and each item in them. It does not compare the types of the input collections.

    .DESCRIPTION
    This assertion verifies that both values are collections and compares their contents rather than their collection types. The items are compared by index, so the order matters. Use `-IgnoreOrder` to compare the items without their order. When you use `-Count`, it only checks the number of items.

    .PARAMETER Expected
    A collection of items.

    .PARAMETER Actual
    A collection of items.

    .PARAMETER IgnoreOrder
    Compares the items without their order, so the same items in a different order pass. Each actual item is used at most once, so a repeated expected item needs at least as many matching items in the actual collection.

    .PARAMETER Count
    Checks if the collection has the expected number of items.

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    1, 2, 3 | Should-BeCollection @(1, 2, 3)
    @(1) | Should-BeCollection @(1)
    1 | Should-BeCollection 1
    ```

    This assertion will pass, because the collections have the same size and the same items in the same order.

    .EXAMPLE
    ```powershell
    1, 2, 3, 4 | Should-BeCollection @(1, 2, 3)
    1, 2, 3, 4 | Should-BeCollection @(5, 6, 7, 8)
    1, 3, 2 | Should-BeCollection @(1, 2, 3)
    @(1) | Should-BeCollection @(2)
    1 | Should-BeCollection @(2)
    ```

    The assertions will fail because the collections are not equal.

    .EXAMPLE
    ```powershell
    1, 3, 2 | Should-BeCollection @(1, 2, 3) -IgnoreOrder
    ```

    This assertion will pass, because with `-IgnoreOrder` the items only have to be the same, not in the same order.

    .NOTES
    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

    .LINK
    https://pester.dev/docs/commands/Should-BeCollection

    .LINK
    https://pester.dev/docs/assertions
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding()]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0, Mandatory, ParameterSetName = 'Expected')]
        $Expected,
        [Parameter(ParameterSetName = 'Expected')]
        [switch] $IgnoreOrder,
        [String]$Because,
        [Parameter(ParameterSetName = 'Count')]
        [int] $Count
    )

    $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input -As 'Collection'
    $Actual = $assert.Actual()

    if (-not (Is-Collection -Value $Actual)) {
        $assert.Fail("Actual <actualType> <actual> is not a collection.", @{ Expected = $Expected; Because = $Because })
    }

    if ($PSCmdlet.ParameterSetName -eq 'Count') {
        if ($Count -ne $Actual.Count) {
            $assert.Fail("Expected <expected> items in <actualType> <actual>,<because> but it has <actualCount> items.", @{ Expected = $Count; Because = $Because; actualCount = $Actual.Count })
        }
        return
    }

    if (-not (Is-Collection -Value $Expected)) {
        $assert.Fail("Expected <expectedType> <expected> is not a collection.", @{ Expected = $Expected; Because = $Because })
    }

    if (-not (Is-CollectionSize -Expected $Expected -Actual $Actual)) {
        $assert.Fail("Expected <expectedType> <expected> to be present in <actualType> <actual>,<because> but they don't have the same number of items.", @{ Expected = $Expected; Because = $Because })
    }

    $actualCopy = [System.Collections.Generic.List[Object]]::new($Actual)
    $expectedCopy = [System.Collections.Generic.List[Object]]::new($Expected)

    $actualLength = $actualCopy.Count
    $expectedLength = $expectedCopy.Count

    if (-not $IgnoreOrder) {
        # `Should -Be` compared arrays item by item in v5 and this keeps that, so a suite that moves
        # from `Should -Be @(1, 2, 3)` to Should-BeCollection keeps checking the order it was
        # checking.
        #
        # LanguagePrimitives::Equals and not -eq. With a collection on the left, -eq filters instead
        # of answering, so `@(,@(9, 9, 1)) | Should-BeCollection @(1)` passed: `@(9, 9, 1) -eq 1`
        # returns `@(1)`, which is true. Equals returns a real bool, says False for that pair, and
        # still says True for `'1'` against `1`.
        #
        # Both lengths bound the loop. Is-CollectionSize compares the originals' Count, which a type
        # could report differently from the number of items the List copies enumerated, and indexing
        # past the end would throw instead of failing the assertion.
        $comparableLength = [System.Math]::Min($actualLength, $expectedLength)
        $differentIndexes = [System.Collections.Generic.List[int]]@()
        for ($i = 0; $i -lt $comparableLength; $i++) {
            if (-not [System.Management.Automation.LanguagePrimitives]::Equals($actualCopy[$i], $expectedCopy[$i])) {
                $differentIndexes.Add($i)
            }
        }

        if (0 -lt $differentIndexes.Count) {
            $actualDifference = $(foreach ($i in $differentIndexes) { "$(Format-Nicely2 $actualCopy[$i]) (index $i)" }) -join ", "
            $expectedDifference = $(foreach ($i in $differentIndexes) { "$(Format-Nicely2 $expectedCopy[$i]) (index $i)" }) -join ", "

            $assert.Fail("Expected <expectedType> <expected> to be present in <actualType> <actual> in the same order,<because> but some items are different.`nExpected: <expectedDifference>`nActual: <actualDifference>", @{ Expected = $Expected; Because = $Because; expectedDifference = $expectedDifference; actualDifference = $actualDifference })
        }

        return
    }

    # If the arrays below have both size 0 we won't go over them,
    # but they are not different. If one of them has size 0 and the other does not
    # we already failed the assertion above.
    #
    # This marks the items that were the same in both arrays, so user can put anything
    # in the array, including $null, and we don't have a conflict, because they can never get
    # reference to the object in $same.
    $same = [Object]::new()
    # go over each item in the array and when found overwrite it in the array
    for ($a = 0; $a -lt $actualLength; $a++) {
        if ($same -eq $actualCopy[$a]) {
            continue
        }
        for ($e = 0; $e -lt $expectedLength; $e++) {
            if ($same -eq $expectedCopy[$e]) {
                continue
            }
            if ($actualCopy[$a] -eq $expectedCopy[$e]) {
                $expectedCopy[$e] = $same
                $actualCopy[$a] = $same
            }
        }
    }

    $different = $false
    for ($a = 0; $a -lt $actualLength; $a++) {
        if ($same -ne $actualCopy[$a]) {
            $different = $true
            break
        }
    }

    if ($different) {
        $actualDifference = $(for ($a = 0; $a -lt $actualLength; $a++) { if ($same -ne $actualCopy[$a]) { "$(Format-Nicely2 $actualCopy[$a]) (index $a)" } }) -join ", "
        $expectedDifference = $(for ($e = 0; $e -lt $actualLength; $e++) { if ($same -ne $expectedCopy[$e]) { "$(Format-Nicely2 $expectedCopy[$e]) (index $e)" } }) -join ", "

        $assert.Fail("Expected <expectedType> <expected> to be present in <actualType> <actual> in any order,<because> but some values were not.`nMissing in actual: <expectedDifference>`nExtra in actual: <actualDifference>", @{ Expected = $Expected; Because = $Because; expectedDifference = $expectedDifference; actualDifference = $actualDifference })
    }
}
