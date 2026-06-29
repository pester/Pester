function Should-Invoke {
    <#
    .SYNOPSIS
    Checks if a Mocked command has been called a certain number of times
    and throws an exception if it has not.

    .DESCRIPTION
    This command verifies that a mocked command has been called a certain number
    of times.  If the call history of the mocked command does not match the parameters
    passed to Should-Invoke, Should-Invoke will throw an exception.

    .PARAMETER CommandName
    The mocked command whose call history should be checked.

    .PARAMETER ModuleName
    The module where the mock being checked was injected. This is optional,
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
    to have two calls to Should-Invoke like this:

    Should-Invoke SomeCommand -Times 1 -ParameterFilter { $something -eq $true }
    Should-Invoke SomeCommand -Times 0 -ParameterFilter { $something -ne $true }

    .PARAMETER Scope
    An optional parameter specifying the Pester scope in which to check for
    calls to the mocked command. For RSpec style tests, Should-Invoke will find
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
    function Save-Report ($Path, $Content) {
        Set-Content -Path $Path -Value $Content
    }

    Describe 'Save-Report' {
        It 'writes the report to disk' {
            Mock Set-Content

            Save-Report -Path 'report.txt' -Content 'All systems green'

            Should-Invoke Set-Content -Times 1 -Exactly
        }
    }
    ```

    Asserts that `Save-Report` wrote to disk by calling the mocked `Set-Content` exactly once. The test fails if `Set-Content` was not called, or was called more than once.

    .EXAMPLE
    ```powershell
    Mock Set-Content

    Save-Report -Path 'report.txt' -Content 'All systems green'

    Should-Invoke Set-Content -ParameterFilter { $Path -eq 'report.txt' }
    ```

    Only the calls where `-Path` was `report.txt` are counted. The assertion passes, because `Save-Report` wrote to that path.

    .EXAMPLE
    ```powershell
    function Get-Weather ($City) {
        Invoke-RestMethod -Uri "https://api.example.com/weather?city=$City"
    }

    Mock Invoke-RestMethod

    Get-Weather -City 'Oslo'

    Should-Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -match 'city=Oslo' }
    ```

    Asserts that the weather API was queried exactly once, and that the request was made for the city of Oslo.

    .EXAMPLE
    ```powershell
    Describe 'Save-Report' {
        BeforeAll { Mock Set-Content }

        It 'writes exactly once per call' {
            Save-Report -Path 'a.txt' -Content 'x'

            Should-Invoke Set-Content -Times 1 -Exactly -Scope It
        }
    }
    ```

    `-Scope It` counts only the calls made in the current `It` block, even though the mock is shared by the whole `Describe`.

    .EXAMPLE
    ```powershell
    Describe 'Publish-Thing' {
        It 'writes from inside the module' {
            Mock -ModuleName Toolbox Set-Content

            Publish-Thing

            Should-Invoke -ModuleName Toolbox Set-Content -Times 1 -Exactly
        }
    }
    ```

    When the command under test lives in a module, both `Mock` and `Should-Invoke` must use the same `-ModuleName` so the recorded call is found.

    .EXAMPLE
    ```powershell
    Mock Remove-Item

    Remove-TempFile -Path "$env:TEMP/old.log"

    Should-Invoke Remove-Item -ExclusiveFilter { $Path -like "$env:TEMP*" }
    ```

    `-ExclusiveFilter` passes only if *every* recorded call matches the filter. Here it asserts that `Remove-Item` was called at least once, and only ever for paths inside the temp folder. It is a shorthand for pairing a `Should-Invoke` and a `Should-NotInvoke`.

    .NOTES
    The parameter filter passed to Should-Invoke does not necessarily have to match the parameter filter
    (if any) which was used to create the Mock.  Should-Invoke will find any entry in the command history
    which matches its parameter filter, regardless of how the Mock was created.  However, if any calls to the
    mocked command are made which did not match any mock's parameter filter (resulting in the original command
    being executed instead of a mock), these calls to the original command are not tracked in the call history.
    In other words, Should-Invoke can only be used to check for calls to the mocked implementation, not
    to the original.

    .LINK
    https://pester.dev/docs/commands/Should-Invoke

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

    if ($PSBoundParameters.ContainsKey('Verifiable')) {
        $PSBoundParameters.Remove('Verifiable')
        $testResult = Should-InvokeVerifiable @PSBoundParameters
        Test-AssertionResult $testResult
        Set-AssertionPassResult
        return
    }

    # Maps the parameters so we can internally use functions that is
    # possible to register as Should operator.
    $PSBoundParameters["ActualValue"] = $null
    $PSBoundParameters["Negate"] = $false
    $PSBoundParameters["CallerSessionState"] = $PSCmdlet.SessionState
    $PSBoundParameters["CommandDisplayName"] = 'Should-Invoke'
    $testResult = Should-InvokeAssertion @PSBoundParameters

    Test-AssertionResult $testResult
    Set-AssertionPassResult
}
