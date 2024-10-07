function Should-BeCollection {
    <#
    .SYNOPSIS
    Compares collections for equality, by comparing their sizes and each item in them. It does not compare the types of the input collections.

    .PARAMETER Expected
    A collection of items.

    .PARAMETER Actual
    A collection of items.

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

    This assertion will pass, because the collections have the same size and the items are equal.

    .EXAMPLE
    ```powershell
    1, 2, 3, 4 | Should-BeCollection @(1, 2, 3)
    1, 2, 3, 4 | Should-BeCollection @(5, 6, 7, 8)
    @(1) | Should-BeCollection @(2)
    1 | Should-BeCollection @(2)
    ```

    The assertions will fail because the collections are not equal.

    .LINK
    https://pester.dev/docs/commands/Should-BeCollection

    .LINK
    https://pester.dev/docs/assertions
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0, Mandatory, ParameterSetName = 'Expected')]
        $Expected,
        [String]$Because,
        [Parameter(ParameterSetName = 'Count')]
        [int] $Count
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput
    $Actual = $collectedInput.Actual

    if (-not (Is-Collection -Value $Actual)) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Actual <actualType> <actual> is not a collection."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    if ($PSCmdlet.ParameterSetName -eq 'Count') {
        if ($Count -ne $Actual.Count) {
            $Message = Get-AssertionMessage -Expected $Count -Actual $Actual -Because $Because -Data @{ actualCount = $Actual.Count } -DefaultMessage "Expected <expected> items in <actualType> <actual>,<because> but it has <actualCount> items."
            throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
        }
        return
    }

    if (-not (Is-Collection -Value $Expected)) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected <expectedType> <expected> is not a collection."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    if (-not (Is-CollectionSize -Expected $Expected -Actual $Actual)) {
        $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected <expectedType> <expected> to be present in <actualType> <actual>,<because> but they don't have the same number of items."
        throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
    }

    if (-Not $InOrder) {

        $actualCopy = [System.Collections.Generic.List[Object]]::new($Actual)
        $expectedCopy = [System.Collections.Generic.List[Object]]::new($Expected)

        $actualLength = $actualCopy.Count
        $expectedLength = $expectedCopy.Count

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

            $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -Data @{ expectedDifference = $expectedDifference; actualDifference = $actualDifference } -DefaultMessage "Expected <expectedType> <expected> to be present in <actualType> <actual> in any order, but some values were not.`nMissing in actual: <expectedDifference>`nExtra in actual: <actualDifference>"
            throw [Pester.Factory]::CreateShouldErrorRecord($Message, $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.Line.TrimEnd([System.Environment]::NewLine), $true)
        }
    }
}
