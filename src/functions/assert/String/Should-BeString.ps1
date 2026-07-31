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

    $expectedExpanded = Expand-SpecialCharacters -InputObject $Expected
    $actualExpanded = Expand-SpecialCharacters -InputObject $Actual

    $prefix = "Expected: '"
    $lines += "$prefix$expectedExpanded'"
    $lines += "But was:  '$actualExpanded'"
    $lines += (' ' * ($prefix.Length - 1)) + ('-' * $differenceIndex) + '^'

    $lines -join "`n"
}
