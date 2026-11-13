function Should-HaveParameter {
    <#
    .SYNOPSIS
    Asserts that a command has the expected parameter.

    .DESCRIPTION
    This assertion inspects command metadata and can also verify parameter details such as type, default value, aliases, parameter set membership, mandatory status, and argument completers.

    .PARAMETER ParameterName
    The name of the parameter to check. E.g. Uri

    .PARAMETER Type
    The type of the parameter to check. E.g. [string]

    .PARAMETER DefaultValue
    The default value of the parameter to check. E.g. "https://example.com"

    .PARAMETER DefaultValueType
    The .NET type of the parameter's default value, as a type or a type name (the same way -Type is given),
    e.g. `([string])`, `[int]`, `bool` or `datetime`. This matches literal defaults whose type is known, so
    `$Force = $false` is `[bool]` and `$Retries = 3` is `[int]`.
    Pass the special value `Expression` for a computed default whose type is not known until it runs, e.g.
    `(Get-Date)`, `[datetime]::Now` or `$someVariable`. `Expression` vs a concrete type is what tells an
    expression default apart from a literal string default, which -DefaultValue (a string comparison)
    cannot: for example `$Path = (Get-DefaultPath)` is an `Expression` while `$Path = '(Get-DefaultPath)'`
    is `[string]`.

    .PARAMETER Mandatory
    Whether the parameter is mandatory or not.

    .PARAMETER InParameterSet
    The parameter set that the parameter belongs to.

    .PARAMETER HasArgumentCompleter
    Whether the parameter has an argument completer or not.

    .PARAMETER Alias
    The alias of the parameter to check.

    .PARAMETER Actual
    The actual command to check. E.g. Get-Command "Invoke-WebRequest"

    .PARAMETER Because
    The reason why the input should be the expected value.

    .EXAMPLE
    ```powershell
    Get-Command Invoke-WebRequest | Should-HaveParameter Uri -Type ([uri]) -Mandatory
    ```

    This assertion passes, because `Invoke-WebRequest` has a mandatory `-Uri` parameter of type `[uri]`.

    .EXAMPLE
    ```powershell
    function Get-Cat {
        [CmdletBinding(DefaultParameterSetName = 'ByName')]
        param(
            [Parameter(ParameterSetName = 'ByName', Mandatory)]
            [Alias('Id')]
            [string] $Name,

            [Parameter(ParameterSetName = 'ByIndex', Mandatory)]
            [int] $Index,

            [ValidateSet('Json', 'Xml')]
            [string] $Format = 'Json'
        )
    }

    Describe 'Get-Cat public contract' {
        It 'requires a Name' {
            Get-Command Get-Cat | Should-HaveParameter Name -Type ([string]) -Mandatory -Alias 'Id'
        }

        It 'defaults Format to Json' {
            Get-Command Get-Cat | Should-HaveParameter Format -Type ([string]) -DefaultValue 'Json'
        }
    }
    ```

    A typical real-life use is locking down the public API of your own command. These assertions pass, because `-Name` is a mandatory `[string]` with the alias `Id`, and `-Format` is an optional `[string]` that defaults to `Json`.

    .EXAMPLE
    ```powershell
    Get-Command Get-Cat | Should-HaveParameter Index -InParameterSet 'ByIndex'
    ```

    This assertion passes, because the `-Index` parameter (from the `Get-Cat` function above) belongs to the `ByIndex` parameter set.

    .NOTES
    The attribute [ArgumentCompleter] was added with PSv5. Previously this
    assertion will not be able to use the -HasArgumentCompleter parameter
    if the attribute does not exist.

    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

    .LINK
    https://pester.dev/docs/commands/Should-HaveParameter

    .LINK
    https://pester.dev/docs/assertions
    #>

    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    [CmdletBinding()]
    param (
        [String] $ParameterName,
        $Type,
        [String] $DefaultValue,
        $DefaultValueType,
        [Switch] $Mandatory,
        [String] $InParameterSet,
        [Switch] $HasArgumentCompleter,
        [String[]] $Alias,
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [String] $Because
    )

    $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
    $Actual = $assert.Actual()

    $PSBoundParameters["ActualValue"] = $Actual
    $PSBoundParameters.Remove("Actual")

    $testResult = Should-HaveParameterAssertion @PSBoundParameters

    if (-not $testResult.Succeeded) {
        $assert.Fail($testResult.FailureMessage)
    }
}
