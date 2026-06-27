function Should-BeHashtable {
    <#
    .SYNOPSIS
    Asserts that the input is a hashtable or dictionary, and optionally checks the number of
    entries, whether it is ordered, and that it contains specific keys.

    .DESCRIPTION
    `Should-BeHashtable` is a shape assertion. It verifies that `$Actual` is a hashtable or
    dictionary (anything implementing `System.Collections.IDictionary`, such as `@{}`,
    `[ordered]@{}` or a generic `Dictionary[,]`).

    It does not compare the contents of the dictionary. Use the optional parameters to assert on
    the shape of the dictionary:

    - `-Count` checks the number of entries.
    - `-Ordered` checks that the value is an ordered dictionary (`[ordered]@{}`).
    - `-Key` checks that the given keys are present, ignoring their values. When combined with
      `-Ordered`, the keys must also appear in the given relative order.

    To compare the keys *and values* of a dictionary against an expected dictionary use
    `Should-BeEquivalent` instead, which performs a deep, order-insensitive comparison.

    .PARAMETER Actual
    The value to test. It is expected to be a hashtable or dictionary.

    .PARAMETER Count
    Checks that the dictionary has the expected number of entries.

    .PARAMETER Ordered
    Checks that the dictionary is an ordered dictionary (`System.Collections.Specialized.OrderedDictionary`),
    as produced by `[ordered]@{}`. A plain `[hashtable]` is unordered and fails this check.

    .PARAMETER Key
    Checks that the dictionary contains the given keys. Only the presence of the keys is checked,
    not their values. When `-Ordered` is also specified, the keys must appear in the dictionary in
    the same relative order as they are listed here.

    .PARAMETER Because
    The reason why the input should be a hashtable with the expected shape.

    .EXAMPLE
    ```powershell
    @{ Name = 'Jakub'; Age = 30 } | Should-BeHashtable
    [ordered]@{ a = 1; b = 2 } | Should-BeHashtable
    ```

    These assertions pass, because the actual value is a hashtable or dictionary.

    .EXAMPLE
    ```powershell
    @{ Name = 'Jakub'; Age = 30 } | Should-BeHashtable -Count 2
    @{ Name = 'Jakub'; Age = 30 } | Should-BeHashtable -Key Name, Age
    [ordered]@{ a = 1; b = 2 } | Should-BeHashtable -Ordered -Key a, b
    ```

    These assertions pass. The dictionary has two entries, it contains the keys `Name` and `Age`,
    and the ordered dictionary contains the keys `a` and `b` in that order.

    .EXAMPLE
    ```powershell
    @{ Name = 'Jakub' } | Should-BeHashtable -Ordered
    @(1, 2, 3) | Should-BeHashtable
    ```

    These assertions fail. The first value is a plain (unordered) hashtable, and the second value
    is a collection, not a hashtable.

    .NOTES
    `Should-BeHashtable` only asserts on the shape of the dictionary. To compare its keys and
    values against an expected dictionary, use `Should-BeEquivalent`.

    .LINK
    https://pester.dev/docs/commands/Should-BeHashtable

    .LINK
    https://pester.dev/docs/assertions
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding()]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [int] $Count,
        [string[]] $Key,
        [switch] $Ordered,
        [String] $Because
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual

    if (-not (Is-Dictionary -Value $Actual)) {
        $Message = Get-AssertionMessage -Expected $null -Actual $Actual -Because $Because -DefaultMessage "Expected a hashtable,<because> but got <actualType> <actual>."
        Invoke-AssertionFailed -Message $Message -CallerCmdlet $PSCmdlet
    }

    if ($Ordered -and ($Actual -isnot [System.Collections.Specialized.OrderedDictionary])) {
        $Message = Get-AssertionMessage -Expected $null -Actual $Actual -Because $Because -DefaultMessage "Expected an ordered hashtable ([ordered]@{}),<because> but got unordered <actualType> <actual>."
        Invoke-AssertionFailed -Message $Message -CallerCmdlet $PSCmdlet
    }

    if ($PSBoundParameters.ContainsKey('Count') -and ($Count -ne $Actual.Count)) {
        $Message = Get-AssertionMessage -Expected $Count -Actual $Actual -Because $Because -Data @{ actualCount = $Actual.Count } -DefaultMessage "Expected <expected> entries in hashtable <actual>,<because> but it has <actualCount> entries."
        Invoke-AssertionFailed -Message $Message -CallerCmdlet $PSCmdlet
    }

    if ($PSBoundParameters.ContainsKey('Key')) {
        $dictionary = [System.Collections.IDictionary]$Actual

        $missingKeys = @(foreach ($k in $Key) { if (-not $dictionary.Contains($k)) { $k } })
        if ($missingKeys.Count -gt 0) {
            $missingFormatted = ($missingKeys | & $SafeCommands['ForEach-Object'] { Format-Nicely2 -Value $_ }) -join ', '
            $keyWord = if ($missingKeys.Count -eq 1) { 'key' } else { 'keys' }
            $Message = Get-AssertionMessage -Expected $Key -Actual $Actual -Because $Because -DefaultMessage "Expected hashtable <actual> to contain $keyWord $missingFormatted,<because> but it does not."
            Invoke-AssertionFailed -Message $Message -CallerCmdlet $PSCmdlet
        }

        # When the dictionary is asserted to be ordered, the requested keys must also appear in the
        # given relative order. Only OrderedDictionary reaches this point (the -Ordered check above
        # rejects anything else), and it compares keys case-insensitively, matching -eq below.
        if ($Ordered) {
            $actualKeys = @($Actual.Keys)
            $positions = foreach ($k in $Key) {
                $found = -1
                for ($i = 0; $i -lt $actualKeys.Count; $i++) {
                    if ($actualKeys[$i] -eq $k) { $found = $i; break }
                }
                $found
            }

            $inOrder = $true
            for ($i = 1; $i -lt $positions.Count; $i++) {
                if ($positions[$i] -le $positions[$i - 1]) { $inOrder = $false; break }
            }

            if (-not $inOrder) {
                $keysFormatted = ($Key | & $SafeCommands['ForEach-Object'] { Format-Nicely2 -Value $_ }) -join ', '
                $actualOrderFormatted = ($actualKeys | & $SafeCommands['ForEach-Object'] { Format-Nicely2 -Value $_ }) -join ', '
                $Message = Get-AssertionMessage -Expected $Key -Actual $Actual -Because $Because -DefaultMessage "Expected keys $keysFormatted to appear in this order in hashtable <actual>,<because> but the actual key order is $actualOrderFormatted."
                Invoke-AssertionFailed -Message $Message -CallerCmdlet $PSCmdlet
            }
        }
    }

    Set-AssertionPassResult
}
