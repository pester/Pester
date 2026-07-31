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

    .EXAMPLE
    ```powershell
    "" | Should-BeString ""
    ```

    This assertion will pass, because an empty string is allowed as the expected value.

    .NOTES
    The `Should-BeString` assertion is the opposite of the `Should-NotBeString` assertion.

    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

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
        [AllowEmptyString()]
        [String]$Expected,
        [String]$Because,
        [switch]$CaseSensitive,
        [switch]$IgnoreWhitespace,
        [switch]$TrimWhitespace
    )

    $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
    $Actual = $assert.Actual()

    $stringsAreEqual = Test-StringEqual -Expected $Expected -Actual $Actual -CaseSensitive:$CaseSensitive -IgnoreWhitespace:$IgnoreWhiteSpace -TrimWhitespace:$TrimWhitespace
    if (-not ($stringsAreEqual)) {
        if ($Actual -is [string]) {
            $assert.Fail((Get-StringDifferenceMessage -Expected $Expected -Actual $Actual -CaseSensitive:$CaseSensitive -Because $Because))
        }
        else {
            $assert.Fail("Expected <expectedType> <expected>, but got <actualType> <actual>.", @{ Expected = $Expected; Because = $Because })
        }
    }
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

    $expectedExpanded = Expand-SpecialCharacters -InputObject $Expected
    $actualExpanded = Expand-SpecialCharacters -InputObject $Actual

    # ConciseView (the default $ErrorView since PowerShell 7.2) reflows the error message: it
    # collapses every newline into a space and re-wraps to the console width. That turns the
    # aligned multi-line diff, including the caret, into an unreadable single line (#2872). No
    # message shape survives that reflow, so under ConciseView we emit a compact single-line
    # message instead, which stays readable once flattened.
    if ('ConciseView' -eq $ErrorView) {
        if ($Expected.Length -ne $Actual.Length) {
            return "Expected strings to be the same,$because but they differ at index $differenceIndex. Expected: '$expectedExpanded' (length $($Expected.Length)), but was: '$actualExpanded' (length $($Actual.Length))."
        }
        return "Expected strings to be the same,$because but they differ at index $differenceIndex. Expected: '$expectedExpanded', but was: '$actualExpanded' (both length $($Expected.Length))."
    }

    $lines = @(
        "Expected strings to be the same,$because but they were different."
    )

    if ($Expected.Length -ne $Actual.Length) {
        $lines += "Expected length: $($Expected.Length)"
        $lines += "Actual length:   $($Actual.Length)"
    }
    else {
        $lines += "String lengths are both $($Expected.Length)."
    }
    $lines += "Strings differ at index $differenceIndex."

    $prefix = "Expected: '"
    $lines += "$prefix$expectedExpanded'"
    $lines += "But was:  '$actualExpanded'"
    # Point the caret at the first differing character. The line content starts at column
    # $prefix.Length (just after the opening quote), so pad by that many spaces, then draw
    # $differenceIndex dashes before the caret. This matches the classic Should -Be caret in
    # Get-CompareStringMessage, which previously pointed one column further right (#2872).
    $lines += (' ' * $prefix.Length) + ('-' * $differenceIndex) + '^'

    $lines -join "`n"
}
