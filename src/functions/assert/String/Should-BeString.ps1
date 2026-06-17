function Test-StringEqual {
    param (
        [String]$Expected,
        $Actual,
        [switch]$CaseSensitive,
        [switch]$IgnoreWhitespace,
        [switch]$TrimWhitespace
    )

    if ($Actual -isnot [string]) {
        return $false
    }

    if ($IgnoreWhitespace) {
        $Expected = $Expected -replace '\s'
        $Actual = $Actual -replace '\s'
    }

    if ($TrimWhitespace) {
        $Expected = $Expected -replace '^\s+|\s+$'
        $Actual = $Actual -replace '^\s+|\s+$'
    }

    if (-not $CaseSensitive) {
        $Expected -eq $Actual
    }
    else {
        $Expected -ceq $Actual
    }
}

function Should-BeString {
    <#
    .SYNOPSIS
    Asserts that the actual value is equal to the expected value.

    .DESCRIPTION
    The `Should-BeString` assertion compares the actual value to the expected value using the `-eq` operator. The `-eq` operator is case-insensitive by default, but you can make it case-sensitive by using the `-CaseSensitive` switch.

    .PARAMETER Expected
    The expected value.

    .PARAMETER Actual
    The actual value.

    .PARAMETER CaseSensitive
    Indicates that the comparison should be case-sensitive.

    .PARAMETER IgnoreWhitespace
    Indicates that the comparison should ignore whitespace.

    .PARAMETER TrimWhitespace
    Trims whitespace at the start and end of the string.

    .PARAMETER Because
    The reason why the actual value should be equal to the expected value.

    .EXAMPLE
    ```powershell
    "hello" | Should-BeString "hello"
    ```

    This assertion will pass, because the actual value is equal to the expected value.

    .EXAMPLE
    ```powershell
    "hello" | Should-BeString "HELLO" -CaseSensitive
    ```

    This assertion will fail, because the actual value is not equal to the expected value.

    .NOTES
    The `Should-BeString` assertion is the opposite of the `Should-NotBeString` assertion.

    .LINK
    https://pester.dev/docs/commands/Should-BeString

    .LINK
    https://pester.dev/docs/assertions
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding()]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0, Mandatory)]
        [String]$Expected,
        [String]$Because,
        [switch]$CaseSensitive,
        [switch]$IgnoreWhitespace,
        [switch]$TrimWhitespace
    )

    $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput
    $Actual = $collectedInput.Actual

    $stringsAreEqual = Test-StringEqual -Expected $Expected -Actual $Actual -CaseSensitive:$CaseSensitive -IgnoreWhitespace:$IgnoreWhiteSpace -TrimWhitespace:$TrimWhitespace
    if (-not ($stringsAreEqual)) {
        if ($Actual -is [string]) {
            $Message = Get-StringDifferenceMessage -Expected $Expected -Actual $Actual -CaseSensitive:$CaseSensitive -Because $Because
        }
        else {
            $Message = Get-AssertionMessage -Expected $Expected -Actual $Actual -Because $Because -DefaultMessage "Expected <expectedType> <expected>, but got <actualType> <actual>."
        }
        Invoke-AssertionFailed -Message $Message -CallerCmdlet $PSCmdlet
    }
    Set-AssertionPassResult
}

function Get-StringDifferenceMessage {
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Expected,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Actual,
        [switch] $CaseSensitive,
        [string] $Because
    )

    $maxLength = [Math]::Max($Expected.Length, $Actual.Length)

    $differenceIndex = $null
    for ($i = 0; $i -lt $maxLength -and ($null -eq $differenceIndex); ++$i) {
        if ($CaseSensitive) {
            if ($Expected[$i] -cne $Actual[$i]) { $differenceIndex = $i }
        }
        else {
            if ($Expected[$i] -ne $Actual[$i]) { $differenceIndex = $i }
        }
    }

    $because = if ($Because) { " because $Because," } else { "" }

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("Expected strings to be the same,$because but they were different.")

    if ($Expected.Length -ne $Actual.Length) {
        $null = $sb.AppendLine("Expected length: $($Expected.Length)")
        $null = $sb.AppendLine("Actual length:   $($Actual.Length)")
    }
    else {
        $null = $sb.AppendLine("String lengths are both $($Expected.Length).")
    }
    $null = $sb.AppendLine("Strings differ at index $differenceIndex.")

    $expectedExpanded = Expand-SpecialCharacters -InputObject $Expected
    $actualExpanded = Expand-SpecialCharacters -InputObject $Actual

    # Recompute difference index on expanded strings
    $maxLength = [Math]::Max($expectedExpanded.Length, $actualExpanded.Length)
    $expandedDiffIndex = $null
    for ($i = 0; $i -lt $maxLength -and ($null -eq $expandedDiffIndex); ++$i) {
        if ($CaseSensitive) {
            if ($expectedExpanded[$i] -cne $actualExpanded[$i]) { $expandedDiffIndex = $i }
        }
        else {
            if ($expectedExpanded[$i] -ne $actualExpanded[$i]) { $expandedDiffIndex = $i }
        }
    }

    $prefix = "Expected: '"
    $null = $sb.AppendLine("$prefix$expectedExpanded'")
    $null = $sb.AppendLine("But was:  '$actualExpanded'")
    $null = $sb.Append((' ' * ($prefix.Length - 1)) + ('-' * $expandedDiffIndex) + '^')

    $sb.ToString()
}
