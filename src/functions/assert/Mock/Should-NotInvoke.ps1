function Should-NotInvoke {
    <#
    .SYNOPSIS
    Checks that mocked command was not called and throws exception if it was.

    .DESCRIPTION
    This command verifies that a mocked command has been called a certain number
    of times.  If the call history of the mocked command does not match the parameters
    passed to Should -Invoke, Should -Invoke will throw an exception.

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
    to have two calls to Should -Invoke like this:

    Should -Invoke SomeCommand -Times 1 -ParameterFilter { $something -eq $true }
    Should -Invoke SomeCommand -Times 0 -ParameterFilter { $something -ne $true }

    .PARAMETER Scope
    An optional parameter specifying the Pester scope in which to check for
    calls to the mocked command. For RSpec style tests, Should -Invoke will find
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
    Mock Set-Content {}

    {... Some Code ...}

    Should -Invoke Set-Content

    This will throw an exception and cause the test to fail if Set-Content is not called in Some Code.

    .EXAMPLE
    Mock Set-Content -parameterFilter {$path.StartsWith("$env:temp\")}

    {... Some Code ...}

    Should -Invoke Set-Content 2 { $path -eq "$env:temp\test.txt" }

    This will throw an exception if some code calls Set-Content on $path=$env:temp\test.txt less than 2 times

    .EXAMPLE
    Mock Set-Content {}

    {... Some Code ...}

    Should -Invoke Set-Content 0

    This will throw an exception if some code calls Set-Content at all

    .EXAMPLE
    Mock Set-Content {}

    {... Some Code ...}

    Should -Invoke Set-Content -Exactly 2

    This will throw an exception if some code does not call Set-Content Exactly two times.

    .EXAMPLE
    Describe 'Should -Invoke Scope behavior' {
        Mock Set-Content { }

        It 'Calls Set-Content at least once in the It block' {
            {... Some Code ...}

            Should -Invoke Set-Content -Exactly 0 -Scope It
        }
    }

    Checks for calls only within the current It block.

    .EXAMPLE
    Describe 'Describe' {
        Mock -ModuleName SomeModule Set-Content { }

        {... Some Code ...}

        It 'Calls Set-Content at least once in the Describe block' {
            Should -Invoke -ModuleName SomeModule Set-Content
        }
    }

    Checks for calls to the mock within the SomeModule module.  Note that both the Mock
    and Should -Invoke commands use the same module name.

    .EXAMPLE
    Should -Invoke Get-ChildItem -ExclusiveFilter { $Path -eq 'C:\' }

    Checks to make sure that Get-ChildItem was called at least one time with
    the -Path parameter set to 'C:\', and that it was not called at all with
    the -Path parameter set to any other value.

    .NOTES
    The parameter filter passed to Should -Invoke does not necessarily have to match the parameter filter
    (if any) which was used to create the Mock.  Should -Invoke will find any entry in the command history
    which matches its parameter filter, regardless of how the Mock was created.  However, if any calls to the
    mocked command are made which did not match any mock's parameter filter (resulting in the original command
    being executed instead of a mock), these calls to the original command are not tracked in the call history.
    In other words, Should -Invoke can only be used to check for calls to the mocked implementation, not
    to the original.

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

    if ($PSBoundParameters.ContainsKey('Verifiable')) {
        $PSBoundParameters.Remove('Verifiable')
        Should-InvokeVerifiable @PSBoundParameters
        return
    }

    # Maps the parameters so we can internally use functions that is
    # possible to register as Should operator.
    $PSBoundParameters["ActualValue"] = $null
    $PSBoundParameters["CallerSessionState"] = $PSCmdlet.SessionState
    Should-InvokeAssertion @PSBoundParameters
}
