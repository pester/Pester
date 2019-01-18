# session state bound functions that act as endpoints,
# so the internal funtions can make their session state
# consumption explicit and are testable (also prevents scrolling past
# the whole documentation :D )

function Get-MockPlugin () {
    Pester.Runtime\New-PluginObject -Name "Mock" `
        -EachBlockSetup {
        (Get-CurrentBlock).PluginData.Mock = @{
            DefinedMocks = @{}
        }
    } -EachTestSetup {
        (Get-CurrentTest).PluginData.Mock = @{
            DefinedMocks = @{}
            CallHistory  = @{}
        }
    }
}

function Mock {

    <#
.SYNOPSIS
Mocks the behavior of an existing command with an alternate
implementation.

.DESCRIPTION
This creates new behavior for any existing command within the scope of a
Describe or Context block. The function allows you to specify a script block
that will become the command's new behavior.

Optionally, you may create a Parameter Filter which will examine the
parameters passed to the mocked command and will invoke the mocked
behavior only if the values of the parameter values pass the filter. If
they do not, the original command implementation will be invoked instead
of a mock.

You may create multiple mocks for the same command, each using a different
ParameterFilter. ParameterFilters will be evaluated in reverse order of
their creation. The last one created will be the first to be evaluated.
The mock of the first filter to pass will be used. The exception to this
rule are Mocks with no filters. They will always be evaluated last since
they will act as a "catch all" mock.

Mocks can be marked Verifiable. If so, the Assert-VerifiableMock command
can be used to check if all Verifiable mocks were actually called. If any
verifiable mock is not called, Assert-VerifiableMock will throw an
exception and indicate all mocks not called.

If you wish to mock commands that are called from inside a script module,
you can do so by using the -ModuleName parameter to the Mock command. This
injects the mock into the specified module. If you do not specify a
module name, the mock will be created in the same scope as the test script.
You may mock the same command multiple times, in different scopes, as needed.
Each module's mock maintains a separate call history and verified status.

.PARAMETER CommandName
The name of the command to be mocked.

.PARAMETER MockWith
A ScriptBlock specifying the behavior that will be used to mock CommandName.
The default is an empty ScriptBlock.
NOTE: Do not specify param or dynamicparam blocks in this script block.
These will be injected automatically based on the signature of the command
being mocked, and the MockWith script block can contain references to the
mocked commands parameter variables.

.PARAMETER Verifiable
When this is set, the mock will be checked when Assert-VerifiableMock is
called.

.PARAMETER ParameterFilter
An optional filter to limit mocking behavior only to usages of
CommandName where the values of the parameters passed to the command
pass the filter.

This ScriptBlock must return a boolean value. See examples for usage.

.PARAMETER ModuleName
Optional string specifying the name of the module where this command
is to be mocked.  This should be a module that _calls_ the mocked
command; it doesn't necessarily have to be the same module which
originally implemented the command.

.EXAMPLE
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} }

Using this Mock, all calls to Get-ChildItem will return a hashtable with a
FullName property returning "A_File.TXT"

.EXAMPLE
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp) }

This Mock will only be applied to Get-ChildItem calls within the user's temp directory.

.EXAMPLE
Mock Set-Content {} -Verifiable -ParameterFilter { $Path -eq "some_path" -and $Value -eq "Expected Value" }

When this mock is used, if the Mock is never invoked and Assert-VerifiableMock is called, an exception will be thrown. The command behavior will do nothing since the ScriptBlock is empty.

.EXAMPLE
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp\1) }
Mock Get-ChildItem { return @{FullName = "B_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp\2) }
Mock Get-ChildItem { return @{FullName = "C_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp\3) }

Multiple mocks of the same command may be used. The parameter filter determines which is invoked. Here, if Get-ChildItem is called on the "2" directory of the temp folder, then B_File.txt will be returned.

.EXAMPLE
Mock Get-ChildItem { return @{FullName="B_File.TXT"} } -ParameterFilter { $Path -eq "$env:temp\me" }
Mock Get-ChildItem { return @{FullName="A_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp) }

Get-ChildItem $env:temp\me

Here, both mocks could apply since both filters will pass. A_File.TXT will be returned because it was the most recent Mock created.

.EXAMPLE
Mock Get-ChildItem { return @{FullName = "B_File.TXT"} } -ParameterFilter { $Path -eq "$env:temp\me" }
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} }

Get-ChildItem c:\windows

Here, A_File.TXT will be returned. Since no filter was specified, it will apply to any call to Get-ChildItem that does not pass another filter.

.EXAMPLE
Mock Get-ChildItem { return @{FullName = "B_File.TXT"} } -ParameterFilter { $Path -eq "$env:temp\me" }
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} }

Get-ChildItem $env:temp\me

Here, B_File.TXT will be returned. Even though the filterless mock was created more recently. This illustrates that filterless Mocks are always evaluated last regardless of their creation order.

.EXAMPLE
Mock Get-ChildItem { return @{FullName = "A_File.TXT"} } -ModuleName MyTestModule

Using this Mock, all calls to Get-ChildItem from within the MyTestModule module
will return a hashtable with a FullName property returning "A_File.TXT"

.EXAMPLE
Get-Module -Name ModuleMockExample | Remove-Module
New-Module -Name ModuleMockExample  -ScriptBlock {
    function Hidden { "Internal Module Function" }
    function Exported { Hidden }

    Export-ModuleMember -Function Exported
} | Import-Module -Force

Describe "ModuleMockExample" {

    It "Hidden function is not directly accessible outside the module" {
        { Hidden } | Should -Throw
    }

    It "Original Hidden function is called" {
        Exported | Should -Be "Internal Module Function"
    }

    It "Hidden is replaced with our implementation" {
        Mock Hidden { "Mocked" } -ModuleName ModuleMockExample
        Exported | Should -Be "Mocked"
    }
}

This example shows how calls to commands made from inside a module can be
mocked by using the -ModuleName parameter.


.LINK
Assert-MockCalled
Assert-VerifiableMock
Describe
Context
It
about_Should
about_Mocking
#>
    [CmdletBinding()]
    param(
        [string]$CommandName,
        [ScriptBlock]$MockWith = {},
        [switch]$Verifiable,
        [ScriptBlock]$ParameterFilter = {$True},
        [string]$ModuleName
    )

    # Assert-DescribeInProgress -CommandName Assert-VerifiableMock

    $SessionState = $PSCmdlet.SessionState
    $null = Set-ScriptBlockHint -Hint "Unbound MockWith - Captured in Mock" -ScriptBlock $MockWith
    $null = Set-ScriptBlockHint -Hint "Unbound ParameterFilter - Captured in Mock" -ScriptBlock $ParameterFilter
    $invokeMockCallBack = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Invoke-Mock', 'function')

    $mockTable = (Get-MockDataForCurrentScope).DefinedMocks

    New-MockInternal @PSBoundParameters -SessionState $SessionState -InvokeMockCallback $invokeMockCallBack -MockTable $mockTable
}

function Get-DefinedMocksTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $CommandName
    )

    # this is used for invoking mocks
    # in there we care about all mocks attached to the current test
    # or any of the mocks above it
    # this does not list mocks in other tests
    $currentTest = Get-CurrentTest
    $currentBlock = Get-CurrentBlock

    $inTest = any $currentTest

    $commandNameFilter = "*||$CommandName"

    $mockTable = @{}

    if ($inTest) {
        foreach ($mock in $currentTest.PluginData.Mock.DefinedMocks.GetEnumerator()) {
            # we are interested in any mock with the given name
            # no matter which module it comes from, it will be filtered
            # down later
            if ($mock.Key -like $commandNameFilter) {
                $mockTable.Add($mock.Key, $mock.Value)
            }
        }
    }

    foreach ($mock in $currentBlock.PluginData.Mock.DefinedMocks.GetEnumerator()) {
        # we are interested in any mock with the given name
        # no matter which module it comes from, it will be filtered
        # down later
        if ($mock.Key -like $commandNameFilter) {
            if (-not ($mockTable.ContainsKey($mock.Key))) {
                $mockTable.Add($mock.Key, $mock.Value)
            }
            else {
                $mockTable[$mock.Key].Blocks += $mock.Value.Blocks
            }
        }
    }

    $mockTable
}


function Get-AssertMockTable {
    [CmdletBinding()]
    param(
        [Switch] $ForceIncludingBlockMock
    )

    # this is used for assertions,
    # in there we care about all mocks attached to the current bloc
    # the current test and all other tests in this block

    $currentTest = Get-CurrentTest
    $inTest = any $currentTest
    # we are in the current test, and did not force assertion for whole block, and we are not running this from one time test teardown
    # so we want to see just mock calls from the current test
    if ($inTest -and -not $ForceIncludingBlockMock -and 'OneTimeTestTeardown' -ne $currentTest.FrameworkData.Runtime.ExecutionStep) {
        return $currentTest.PluginData.Mock.CallHistory
    }

    $currentBlock = Get-CurrentBlock
    $merged = @{}
    if (any $currentBlock.PluginData.Mock.CallHistory) {
        Merge-HashTable -Source $currentBlock.PluginData.Mock.CallHistory -Destination $merged
    }

    foreach ($test in $currentBlock.Tests) {
        if (any $test.PluginData.Mock.CallHistory) {
            foreach ($pair in $test.PluginData.Mock.CallHistory.GetEnumerator()) {
                if ($merged.ContainsKey($pair.Key)) {
                    $merged[$pair.Key] += $pair.Value
                }
                else {
                    $merged.Add($pair.Key, $pair.Value)
                }
            }
        }
    }

    # merge them into a new one with per block taking precedence
    # but can we even define mock in test when the same is in the block already?
    $merged
}

function Get-MockDataForCurrentScope {
    [CmdletBinding()]
    param(
    )

    # this returns a mock table based on location, that we
    # then use to add the mock into, keep in mind that what we
    # pass must be a reference, so the data are persisted in the
    # inner state

    # if I forget how this works, then I aggregate the result in the
    # location variable, so if I am not in a test or  I am currently
    # in one time test setup I return the table from the block and not
    # the table from the test, this way the mock gets defined for the
    # whole block, as expected for one time setup, and the $location
    # variable allows me to easily see if I am in neither test and block
    # and still get away without keeping extra boolean variables that indicate
    # what path I took in the code

    $location = $currentTest = Get-CurrentTest

    if ((none $currentTest) -or 'OneTimeTestSetup' -eq $currentTest.FrameworkData.Runtime.ExecutionStep) {
        $location = $currentBlock = Get-CurrentBlock
    }

    if (none @($currentTest, $currentBlock)) {
        throw "I am neither in a test or a block, where am I?"
    }

    $location.PluginData.Mock
}


function Assert-VerifiableMock {
    <#
.SYNOPSIS
Checks if any Verifiable Mock has not been invoked. If so, this will throw an exception.

.DESCRIPTION
This can be used in tandem with the -Verifiable switch of the Mock
function. Mock can be used to mock the behavior of an existing command
and optionally take a -Verifiable switch. When Assert-VerifiableMock
is called, it checks to see if any Mock marked Verifiable has not been
invoked. If any mocks have been found that specified -Verifiable and
have not been invoked, an exception will be thrown.

.EXAMPLE
Mock Set-Content {} -Verifiable -ParameterFilter {$Path -eq "some_path" -and $Value -eq "Expected Value"}

{ ...some code that never calls Set-Content some_path -Value "Expected Value"... }

Assert-VerifiableMock

This will throw an exception and cause the test to fail.

.EXAMPLE
Mock Set-Content {} -Verifiable -ParameterFilter {$Path -eq "some_path" -and $Value -eq "Expected Value"}

Set-Content some_path -Value "Expected Value"

Assert-VerifiableMock

This will not throw an exception because the mock was invoked.

#>
    [CmdletBinding()]param()

    Assert-DescribeInProgress -CommandName Assert-VerifiableMock

    # TODO : figure out what mock table to use
    Assert-VerifiableMockInternal -MockTable $MockTable
}

function Assert-MockCalled {
    <#
.SYNOPSIS
Checks if a Mocked command has been called a certain number of times
and throws an exception if it has not.

.DESCRIPTION
This command verifies that a mocked command has been called a certain number
of times.  If the call history of the mocked command does not match the parameters
passed to Assert-MockCalled, Assert-MockCalled will throw an exception.

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
to have two calls to Assert-MockCalled like this:

Assert-MockCalled SomeCommand -Times 1 -ParameterFilter { $something -eq $true }
Assert-MockCalled SomeCommand -Times 0 -ParameterFilter { $something -ne $true }

.PARAMETER Scope
An optional parameter specifying the Pester scope in which to check for
calls to the mocked command. For RSpec style tests, Assert-MockCalled will find
all calls to the mocked command in the current Context block (if present),
or the current Describe block (if there is no active Context), by default. Valid
values are Describe, Context and It. If you use a scope of Describe or
Context, the command will identify all calls to the mocked command in the
current Describe / Context block, as well as all child scopes of that block.

For Gherkin style tests, Assert-MockCalled will find all calls to the mocked
command in the current Scenario block or the current Feature block (if there is
no active Scenario), by default. Valid values for Gherkin style tests are Feature
and Scenario. If you use a scope of Feature or Scenario, the command will identify
all calls to the mocked command in the current Feature / Scenario block, as well
as all child scopes of that block.

.EXAMPLE
C:\PS>Mock Set-Content {}

{... Some Code ...}

C:\PS>Assert-MockCalled Set-Content

This will throw an exception and cause the test to fail if Set-Content is not called in Some Code.

.EXAMPLE
C:\PS>Mock Set-Content -parameterFilter {$path.StartsWith("$env:temp\")}

{... Some Code ...}

C:\PS>Assert-MockCalled Set-Content 2 { $path -eq "$env:temp\test.txt" }

This will throw an exception if some code calls Set-Content on $path=$env:temp\test.txt less than 2 times

.EXAMPLE
C:\PS>Mock Set-Content {}

{... Some Code ...}

C:\PS>Assert-MockCalled Set-Content 0

This will throw an exception if some code calls Set-Content at all

.EXAMPLE
C:\PS>Mock Set-Content {}

{... Some Code ...}

C:\PS>Assert-MockCalled Set-Content -Exactly 2

This will throw an exception if some code does not call Set-Content Exactly two times.

.EXAMPLE
Describe 'Assert-MockCalled Scope behavior' {
    Mock Set-Content { }

    It 'Calls Set-Content at least once in the It block' {
        {... Some Code ...}

        Assert-MockCalled Set-Content -Exactly 0 -Scope It
    }
}

Checks for calls only within the current It block.

.EXAMPLE
Describe 'Describe' {
    Mock -ModuleName SomeModule Set-Content { }

    {... Some Code ...}

    It 'Calls Set-Content at least once in the Describe block' {
        Assert-MockCalled -ModuleName SomeModule Set-Content
    }
}

Checks for calls to the mock within the SomeModule module.  Note that both the Mock
and Assert-MockCalled commands use the same module name.

.EXAMPLE
Assert-MockCalled Get-ChildItem -ExclusiveFilter { $Path -eq 'C:\' }

Checks to make sure that Get-ChildItem was called at least one time with
the -Path parameter set to 'C:\', and that it was not called at all with
the -Path parameter set to any other value.

.NOTES
The parameter filter passed to Assert-MockCalled does not necessarily have to match the parameter filter
(if any) which was used to create the Mock.  Assert-MockCalled will find any entry in the command history
which matches its parameter filter, regardless of how the Mock was created.  However, if any calls to the
mocked command are made which did not match any mock's parameter filter (resulting in the original command
being executed instead of a mock), these calls to the original command are not tracked in the call history.
In other words, Assert-MockCalled can only be used to check for calls to the mocked implementation, not
to the original.

#>

    [CmdletBinding(DefaultParameterSetName = 'ParameterFilter')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$CommandName,

        [Parameter(Position = 1)]
        [int]$Times = 1,

        [ScriptBlock]$ParameterFilter = {$True},

        [Parameter(ParameterSetName = 'ExclusiveFilter', Mandatory = $true)]
        [scriptblock] $ExclusiveFilter,

        [string] $ModuleName,

        [ValidateSet('Describe', 'Context', 'It')]
        [string] $Scope = "It",
        [switch] $Exactly
    )

    #  Assert-DescribeInProgress -CommandName Assert-VerifiableMock

    $force = "Describe", "Context" -contains $Scope
    $mockTable = Get-AssertMockTable -ForceIncludingBlockMock:$force

    if ($PSBoundParameters.ContainsKey("Scope")) {
        $PSBoundParameters.Remove("Scope")
    }

    Assert-MockCalledInternal @PSBoundParameters -MockTable $mockTable -SessionState $pester.SessionState # or should this be the caller state?
}

function Invoke-Mock {
    <#
        .SYNOPSIS
        This command is used by Pester's Mocking framework.  You do not need to call it directly.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $CommandName,

        [Parameter(Mandatory = $true)]
        [hashtable] $MockCallState,

        [string]
        $ModuleName,

        [hashtable]
        $BoundParameters = @{},

        [object[]]
        $ArgumentList = @(),

        [object] $CallerSessionState,

        [ValidateSet('Begin', 'Process', 'End')]
        [string] $FromBlock,

        [object] $InputObject
    )


    # this function is called by the mock bootstrap function, so every implementer
    # should implement this (but I keep it separate from the core function so I can)
    # test without dependency on scopes, this can probably just become a callback, but where
    # should it be registered?

    $mockTable = Get-DefinedMocksTable -CommandName $CommandName
    $callHistoryTable = (Get-MockDataForCurrentScope).CallHistory

    Invoke-MockInternal  @PSBoundParameters -MockTable $mockTable -CallHistoryTable $callHistoryTable -SessionState $pester.SessionState # or caller state??
}


