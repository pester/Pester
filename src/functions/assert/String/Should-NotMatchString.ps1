function Test-NotMatchString {
    param (
        [String]$Expected,
        $Actual,
        [switch]$CaseSensitive
    )

    if (-not $CaseSensitive) {
        $Actual -notmatch $Expected
    }
    else {
        $Actual -cnotmatch $Expected
    }
}

function Should-NotMatchString {
    <#
    .SYNOPSIS
    Tests whether a string does not match a regular expression pattern.

    .DESCRIPTION
    The `Should-NotMatchString` assertion compares the actual string to the expected regular expression pattern using the `-notmatch` operator. The `-notmatch` operator is case-insensitive by default, but you can make it case-sensitive by using the `-CaseSensitive` switch.

    .PARAMETER Expected
    The expected regular expression pattern.

    .PARAMETER Actual
    The actual value.

    .PARAMETER CaseSensitive
    Indicates that the comparison should be case-sensitive.

    .PARAMETER Because
    The reason why the actual value should not match the regular expression pattern.

    .EXAMPLE
    ```powershell
    'Hello Jakub, your order #4821 shipped.' | Should-NotMatchString '\{\{.*?\}\}'
    ```

    This assertion passes, because the rendered text contains no leftover `{{ ... }}` template placeholders. This is a common check after expanding a template to make sure every token was replaced.

    .EXAMPLE
    ```powershell
    'level=info msg="started"' | Should-NotMatchString 'password='
    ```

    This assertion passes, because the log line does not leak a `password=` value.

    .EXAMPLE
    ```powershell
    'Build failed' | Should-NotMatchString 'failed' -CaseSensitive
    ```

    This assertion fails, because the actual value case-sensitively contains `failed`.

    .NOTES
    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

    .LINK
    https://pester.dev/docs/commands/Should-NotMatchString

    .LINK
    https://pester.dev/docs/assertions
    #>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding()]
    param (
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Position = 0, Mandatory = $true)]
        $Expected,
        [Switch]$CaseSensitive,
        [String]$Because
    )

    $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
    $Actual = $assert.Actual()

    if ($Actual -isnot [string]) {
        throw [ArgumentException]"Actual is expected to be string, to avoid confusing behavior that -match operator exhibits with collections. To assert on collections use Should-Any, Should-All or some other collection assertion."
    }

    if ($Expected -isnot [string]) {
        throw [ArgumentException]"Expected is expected to be string, to avoid confusing behavior that -match operator exhibits with collections."
    }

    $stringsDoNotMatch = Test-NotMatchString -Expected $Expected -Actual $Actual -CaseSensitive:$CaseSensitive
    if (-not $stringsDoNotMatch) {
        $caseSensitiveMessage = ""
        if ($CaseSensitive) {
            $caseSensitiveMessage = " case sensitively"
        }

        $assert.Fail("Expected the string '$Actual' to$caseSensitiveMessage not match pattern '$Expected',<because> but it matched it.", @{ Because = $Because })
    }
}
