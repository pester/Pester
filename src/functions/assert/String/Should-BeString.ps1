function Test-StringEqual {
    param (
        [String]$Expected,
        $Actual,
        [switch]$CaseSensitive,
        [switch]$IgnoreWhitespace,
        [switch]$TrimWhitespace,
        [switch]$NormalizeLineEnding
    )

    if ($Actual -isnot [string]) {
        return $false
    }

    if ($NormalizeLineEnding) {
        $Expected = $Expected -replace '\r\n|\r|\p{Zl}', "`n"
        $Actual = $Actual -replace '\r\n|\r|\p{Zl}', "`n"
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

    .PARAMETER NormalizeLineEnding
    Normalizes line endings before comparison, so that `\r\n`, `\r`, and the Unicode line separator are all treated as `\n`. Use this to compare multi-line strings across platforms without failing on line-ending style. Unlike `-IgnoreWhitespace`, the newlines and their positions are kept, so indentation and blank lines are still compared.

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
        [switch]$TrimWhitespace,
        [switch]$NormalizeLineEnding
    )

    $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
    $Actual = $assert.Actual()

    $stringsAreEqual = Test-StringEqual -Expected $Expected -Actual $Actual -CaseSensitive:$CaseSensitive -IgnoreWhitespace:$IgnoreWhiteSpace -TrimWhitespace:$TrimWhitespace -NormalizeLineEnding:$NormalizeLineEnding
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

    # Big strings get a compact view. Printing both in full is what makes a 10 000 line comparison
    # useless (#2951), but for a short string the full text with a caret under the difference is
    # more precise than anything else, so that is left exactly as it was.
    $expectedLines = $Expected -split '\r\n|\r|\n'
    $actualLines = $Actual -split '\r\n|\r|\n'
    $maxLines = [Math]::Max($expectedLines.Count, $actualLines.Count)
    $isBig = 10 -lt $maxLines -or 120 -lt $maxLength

    if ($isBig -and 1 -lt $maxLines) {
        $lineCount = $maxLines

        $differenceLine = $null
        for ($i = 0; $i -lt $lineCount -and ($null -eq $differenceLine); ++$i) {
            $e = if ($i -lt $expectedLines.Count) { $expectedLines[$i] } else { $null }
            $a = if ($i -lt $actualLines.Count) { $actualLines[$i] } else { $null }
            $same = if ($CaseSensitive) { $e -ceq $a } else { $e -eq $a }
            if (-not $same) { $differenceLine = $i }
        }

        $lines += "Expected $($expectedLines.Count) line(s), actual $($actualLines.Count) line(s)."

        if ($null -eq $differenceLine) {
            # Every line is equal, so what differs is the line endings themselves. Splitting on them
            # threw away the only difference there is, and showing the lines would print two blocks
            # that look identical. Name the endings instead.
            $describeEndings = {
                param ([string] $Value)
                $crlf = ([regex]::Matches($Value, "`r`n")).Count
                $cr = ([regex]::Matches($Value, "`r(?!`n)")).Count
                $lf = ([regex]::Matches($Value, "(?<!`r)`n")).Count
                (@(
                        if (0 -lt $crlf) { "$crlf CRLF" }
                        if (0 -lt $cr) { "$cr CR" }
                        if (0 -lt $lf) { "$lf LF" }
                    ) -join ', ')
            }

            $lines += "Every line is the same, only the line endings differ."
            $lines += "Expected: $(& $describeEndings $Expected)"
            $lines += "But was:  $(& $describeEndings $Actual)"
            $lines += "Use -NormalizeLineEnding to ignore this."
            return $lines -join "`n"
        }

        $lines += "Lines differ at line $($differenceLine + 1)."
        $lines += ""

        $context = 2
        $from = [Math]::Max(0, $differenceLine - $context)
        $to = [Math]::Min($lineCount - 1, $differenceLine + $context)
        $width = ($to + 1).ToString().Length

        for ($i = $from; $i -le $to; ++$i) {
            $e = if ($i -lt $expectedLines.Count) { $expectedLines[$i] } else { $null }
            $a = if ($i -lt $actualLines.Count) { $actualLines[$i] } else { $null }
            $number = ($i + 1).ToString().PadLeft($width)

            if ($i -eq $differenceLine) {
                # Expand only the lines that differ, so an invisible difference (a stray \r, a
                # trailing space) is visible without turning every other line into escape codes.
                $lines += "  $number | - $(Expand-SpecialCharacters -InputObject ([string]$e))"
                $lines += "  $(' ' * $width) | + $(Expand-SpecialCharacters -InputObject ([string]$a))"
            }
            else {
                $lines += "  $number |   $e"
            }
        }

        return $lines -join "`n"
    }

    $lines += "Strings differ at index $differenceIndex."

    $expectedExpanded = Expand-SpecialCharacters -InputObject $Expected
    $actualExpanded = Expand-SpecialCharacters -InputObject $Actual

    $prefix = "Expected: '"

    if (-not $isBig) {
        # Short enough to print whole, which is the most precise thing we can show.
        $lines += "$prefix$expectedExpanded'"
        $lines += "But was:  '$actualExpanded'"
        $lines += (' ' * $prefix.Length) + ('-' * $differenceIndex) + '^'
        return $lines -join "`n"
    }

    # Long. Show a window around the difference rather than the whole string, the way
    # Should -BeExactly does in v5, so it stays readable.
    $ellipsis = "..."
    $window = 40

    $start = [Math]::Max(0, $differenceIndex - $window)
    $caretOffset = $differenceIndex - $start

    $excerpt = {
        param ([string] $Value)
        $end = [Math]::Min($Value.Length, $start + $window * 2)
        $text = if ($start -lt $Value.Length) { $Value.Substring($start, $end - $start) } else { "" }
        $head = if (0 -lt $start) { $ellipsis } else { "" }
        $tail = if ($end -lt $Value.Length) { $ellipsis } else { "" }
        "$head$text$tail"
    }

    $expectedExcerpt = & $excerpt $expectedExpanded
    $actualExcerpt = & $excerpt $actualExpanded
    $caretPad = $caretOffset + $(if (0 -lt $start) { $ellipsis.Length } else { 0 })

    $lines += "$prefix$expectedExcerpt'"
    $lines += "But was:  '$actualExcerpt'"
    $lines += (' ' * $prefix.Length) + ('-' * $caretPad) + '^'

    $lines -join "`n"
}
