function Should-NotInvoke {
    <#
    .SYNOPSIS
    Checks that mocked command was not called and throws exception if it was.

    .DESCRIPTION
    This command verifies that a mocked command has not been called a certain number
    of times.  If the call history of the mocked command does not match the parameters
    passed to Should-NotInvoke, Should-NotInvoke will throw an exception.

    .PARAMETER CommandName
    The mocked command whose call history should be checked.

    .PARAMETER ModuleName
    The module where the mock being checked was injected.  This is optional,
    and must match the ModuleName that was used when setting up the Mock.

    .PARAMETER Times
    The number of times that the mock must be called to avoid an exception
    from throwing.

    .PARAMETER Exactly
    If this switch is present, the number specified in Times must match
    exactly the number of times the mock has been called. Otherwise it
    must match "at least" the number of times specified.  If the value
    passed to the Times parameter is zero, the Exactly switch is implied.

    .PARAMETER ParameterFilter
    An optional filter to qualify which calls should be counted. Only those
    calls to the mock whose parameters cause this filter to return true
    will be counted.

    .PARAMETER ExclusiveFilter
    Like ParameterFilter, except when you use ExclusiveFilter, and there
    were any calls to the mocked command which do not match the filter,
    an exception will be thrown.  This is a convenient way to avoid needing
    to have two calls to Should-NotInvoke like this:

    Should-NotInvoke SomeCommand -Times 1 -ParameterFilter { $something -eq $true }
    Should-NotInvoke SomeCommand -Times 0 -ParameterFilter { $something -ne $true }

    .PARAMETER Scope
    An optional parameter specifying the Pester scope in which to check for
    calls to the mocked command. For RSpec style tests, Should-NotInvoke will find
    all calls to the mocked command in the current Context block (if present),
    or the current Describe block (if there is no active Context), by default. Valid
    values are Describe, Context and It. If you use a scope of Describe or
    Context, the command will identify all calls to the mocked command in the
    current Describe / Context block, as well as all child scopes of that block.

    .PARAMETER Because
    The reason why the mock should be called.

    .PARAMETER Verifiable
    Makes sure that all verifiable mocks were called.

    .EXAMPLE
    ```powershell
    function Remove-TempFile ($Path, [switch] $WhatIf) {
        if (-not $WhatIf) { Remove-Item -Path $Path }
    }

    Describe 'Remove-TempFile' {
        It 'does not delete anything in -WhatIf mode' {
            Mock Remove-Item

            Remove-TempFile -Path 'temp.txt' -WhatIf

            Should-NotInvoke Remove-Item
        }
    }
    ```

    Because `-WhatIf` was passed, `Remove-TempFile` must not delete anything. The assertion passes when the mocked `Remove-Item` was never called, and throws (failing the test) if it was called.

    .EXAMPLE
    ```powershell
    Mock Remove-Item

    Remove-TempFile -Path "$env:TEMP/old.log"

    Should-NotInvoke Remove-Item -ParameterFilter { $Path -notlike "$env:TEMP*" }
    ```

    Only the calls whose `-Path` is outside the temp folder are counted. The assertion passes, because `Remove-TempFile` only ever deletes inside `$env:TEMP`.

    .EXAMPLE
    ```powershell
    Describe 'Remove-TempFile' {
        BeforeAll { Mock Remove-Item }

        It 'is a no-op in -WhatIf mode' {
            Remove-TempFile -Path 'temp.txt' -WhatIf

            Should-NotInvoke Remove-Item -Scope It
        }
    }
    ```

    `-Scope It` limits the check to calls made in the current `It` block, even when the mock is shared across the whole `Describe`.

    .NOTES
    The parameter filter passed to Should-NotInvoke does not necessarily have to match the parameter filter
    (if any) which was used to create the Mock.  Should-NotInvoke will find any entry in the command history
    which matches its parameter filter, regardless of how the Mock was created.  However, if any calls to the
    mocked command are made which did not match any mock's parameter filter (resulting in the original command
    being executed instead of a mock), these calls to the original command are not tracked in the call history.
    In other words, Should-NotInvoke can only be used to check for calls to the mocked implementation, not
    to the original.

    Use the `-ErrorAction` parameter to control soft-assertion behavior for this assertion. `-ErrorAction Continue` records the failure and lets the rest of the test run (a soft assertion), while `-ErrorAction Stop` fails the test immediately, for example to guard a precondition before continuing.

    When `-ErrorAction` is not specified, the behavior comes from `Should.ErrorAction` in the configuration, which defaults to `Stop`. See https://pester.dev/docs/assertions/soft-assertions for more about soft assertions.

    .LINK
    https://pester.dev/docs/commands/Should-NotInvoke

    .LINK
    https://pester.dev/docs/assertions
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Default')]
        [string]$CommandName,

        [Parameter(Position = 1, ParameterSetName = 'Default')]
        [int]$Times = 1,

        [parameter(ParameterSetName = 'Default')]
        [ScriptBlock]$ParameterFilter = { $True },

        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'ExclusiveFilter', Mandatory = $true)]
        [scriptblock] $ExclusiveFilter,

        [Parameter(ParameterSetName = 'Default')]
        [string] $ModuleName,
        [Parameter(ParameterSetName = 'Default')]
        [string] $Scope = 0,
        [Parameter(ParameterSetName = 'Default')]
        [switch] $Exactly,
        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'Verifiable')]
        [string] $Because,

        [Parameter(ParameterSetName = 'Verifiable')]
        [switch] $Verifiable
    )

    $PSBoundParameters["Negate"] = $true

    $assert = New-ShouldAssertion -Caller $PSCmdlet -Buffer $local:Input

    if ($PSBoundParameters.ContainsKey('Verifiable')) {
        $PSBoundParameters.Remove('Verifiable')
        $testResult = Should-InvokeVerifiable @PSBoundParameters
        if (-not $testResult.Succeeded) {
            $assert.Fail($testResult.FailureMessage)
        }
        return
    }

    # Maps the parameters so we can internally use functions that is
    # possible to register as Should operator.
    $PSBoundParameters["ActualValue"] = $null
    $PSBoundParameters["CallerSessionState"] = $PSCmdlet.SessionState
    $PSBoundParameters["CommandDisplayName"] = 'Should-NotInvoke'
    $testResult = Should-InvokeAssertion @PSBoundParameters

    if (-not $testResult.Succeeded) {
        $assert.Fail($testResult.FailureMessage)
    }
}
