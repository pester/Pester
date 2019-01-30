# session state bound functions that act as endpoints,
# so the internal funtions can make their session state
# consumption explicit and are testable (also prevents scrolling past
# the whole documentation :D )

function Get-MockPlugin () {
    Pester.Runtime\New-PluginObject -Name "Mock" `
        -EachBlockSetup {
        param($Context)
        $Context.Block.PluginData.Mock = @{
            DefinedMocks = @{}
            CallHistory  = @{}
        }
    } -EachTestSetup {
        param($Context)
        $Context.Test.PluginData.Mock = @{
            DefinedMocks = @{}
            CallHistory  = @{}
        }
    } -EachTestTeardown {
        param($Context)
        # we are defining that table in the setup but the teardowns
        # need to be resilient, because they will run even if the setups
        # did not run
        $mockTable = $Context.Test.PluginData.Mock.DefinedMocks
        if ($null -ne $mockTable) {
            Exit-MockScope -MockTable $mockTable
        }
    } -EachBlockTeardown {
        param($Context)
        $mockTable = $Context.Block.PluginData.Mock.DefinedMocks
        if ($null -ne $mockTable) {
            Exit-MockScope -MockTable $mockTable
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

    Assert-RunInProgress -CommandName Mock

    Write-PesterDebugMessage -Scope Mock -Message "Setting up mock for$(if ($ModuleName) {" $ModuleName -"}) $CommandName."
    $SessionState = $PSCmdlet.SessionState
    $null = Set-ScriptBlockHint -Hint "Unbound MockWith - Captured in Mock" -ScriptBlock $MockWith
    $null = Set-ScriptBlockHint -Hint "Unbound ParameterFilter - Captured in Mock" -ScriptBlock $ParameterFilter
    $invokeMockCallBack = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Invoke-Mock', 'function')

    # don't try to filter here, the passed table is written into, and so it must me a live reference
    $mockTable = (Get-MockDataForCurrentScope).DefinedMocks


    New-MockInternal @PSBoundParameters -SessionState $SessionState -InvokeMockCallback $invokeMockCallBack -MockTable $mockTable
}

function Get-DefinedMocksTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $CommandName
    )

    Write-PesterDebugMessage -Scope Mock "Getting all defined mocks in this and parent scopes for command $CommandName."
    # this is used for invoking mocks
    # in there we care about all mocks attached to the current test
    # or any of the mocks above it
    # this does not list mocks in other tests
    $currentTest = Get-CurrentTest
    $inTest = any $currentTest

    # do not use like "*||$CommandName" here, it will not match functions with wildcard
    # characters in them like function f[f]f
    $commandNameFilter = "^.*?\|\|$([regex]::Escape($CommandName))$"

    $mockTable = @{}

    if ($inTest) {
        Write-PesterDebugMessage -Scope Mock "We are in a test. Finding all mocks in this test."
        foreach ($mock in $currentTest.PluginData.Mock.DefinedMocks.GetEnumerator()) {
            # we are interested in any mock with the given name
            # no matter which module it comes from, it will be filtered
            # down later
            if ($mock.Key -match $commandNameFilter) {
                Write-PesterDebugMessage -Scope Mock "Found mock data for $($mock.Key) in the test."
                $mockTable.Add($mock.Key, $mock.Value)
            }
            else {
                Write-PesterDebugMessage -Scope Mock "Found no mocks for $CommandName in this test."
            }
        }
    }

    Write-PesterDebugMessage -Scope Mock "Finding all mocks in this block."
    $blockMockTables = Recurse-Up (Get-CurrentBlock) {
        param($b)

        if ($b.PluginData -and $b.PluginData.Mock) {
            $mocks = $b.PluginData.Mock.DefinedMocks
            foreach ($m in $mocks.GetEnumerator()) {
                # we are interested in any mock with the given name
                # no matter which module it comes from, it will be filtered
                # down later
                if ($m.Key -match $commandNameFilter) {
                    Write-PesterDebugMessage -Scope Mock "Found mock $($m.Key) in $($b.Name)."
                    $m
                }
            }
        }
    }

    if (none $blockMockTables) {
        Write-PesterDebugMessage -Scope Mock "No mocks for $CommandName were found in this or any parent blocks."
    }

    Write-PesterDebugMessage -Scope Mock "Merging mock definitions from blocks and tests into resulting mock table."
    foreach ($blockMockTable in $blockMockTables) {
        foreach ($mock in $blockMockTable) {
            if (-not ($mockTable.ContainsKey($mock.Key))) {
                $mockTable.Add($mock.Key, $mock.Value)
            }
            else {
                $mockTable[$mock.Key].Blocks += $mock.Value.Blocks
            }
        }
    }

    Write-PesterDebugMessage -Scope Mock -LazyMessage {
        "Found mocks: "
        foreach ($table in $mockTable.GetEnumerator()) {
            "$($table.Key):"
            "Command name: $($table.Value.CommandName)"
            "Aliases: $($table.Value.Aliases -join ",")"
            "Bootstrap function: $($table.Value.BootstrapFunctionName)"
            "mocked with $($table.Value.Blocks.Count) mocks:"

            foreach ($block in $table.Value.Blocks) {
                "`tBody: { $($block.ScriptBlock.ToString().Trim()) }"
                "`tFilter: { $($block.Filter.ToString().Trim()) }"
                "`tVerifiable: $($block.Verifiable)"
            }
        }
    }

    $mockTable
}


function Get-AssertMockTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Frame,
        [Parameter(Mandatory)]
        [String] $CommandName,
        [String] $ModuleName
    )
    # frame looks like this
    # [PSCustomObject]@{
    #     Scope = int
    #     Frame = block | test
    #     IsTest = bool
    # }

    $key = "$resolvedModule||$resolvedCommand"
    $scope = $Frame.Scope
    $inTest = $Frame.IsTest
    # this is used for assertions, in here we need to collect
    # all call histories for the given command in the scope.
    # if the scope number is bigger than 0 then we need all
    # in the whole scope including all its

    if ($inTest -and 0 -eq $scope) {
        # we are in test and we care only about the test scope,
        # this is easy, we just look for call history of the command

        $history = tryGetValue $Frame.Frame.PluginData.Mock.CallHistory $key
        if ($history) {
            return @{
                "$key" = @($history)
            }
        }
        else {
            $test = $Frame.Frame
            $mockInTest = tryGetValue $test.PluginData.Mock.DefinedMocks $key
            if ($mockInTest) {
                # the mock was defined in it but it was not called in this scope
                return @{
                    "$key" = @()
                }
            }
            else {
                # try finding the mock definition in upper scopes, because it was not found in the current test
                $mockInBlock = Recurse-Up $test.Block {
                    param ($b)
                    if ((tryGetProperty $b.PluginData Mock) -and (tryGetProperty $b.PluginData.Mock DefinedMocks)) {
                        tryGetValue $b.PluginData.Mock.DefinedMocks $key
                    }
                }

                if (none $mockInBlock) {
                    throw "Could not find any mock definition for $CommandName$(if ($ModuleName) { " from module $ModuleName"})."
                }
                else {
                     # the mock was defined in some upper scope but it was not called in this it
                    return @{
                        "$key" = @()
                    }
                }
            }
        }
    }


    # this is harder, we have scope and we are in a block, we need to look
    # in this block and any child for mock calls

    $currentBlock = if ($inTest) { $Frame.Frame.Block } else { $Frame.Frame }
    if ($inTest) {
        # we are in test but we only inspect blocks, so getting current block automatically
        # makes us in scope 1, so if we got 1 from the parameter we need to translate it to 0
        $scope -= 1
    }

    if ($scope -eq 0) {
        # in scope 0 the current block is the base block
        $block = $currentBlock
    }
    if ($scope -eq 1) {
        # in scope 1 it is the parent
        $block = if (any $currentBlock.Parent) { $currentBlock.Parent } else { $currentBlock }
    }
    else {
        # otherwise we just walk up as many scopes as needed until
        # we reach the desired scope, or the root of the tree, the above ifs could
        # be replaced by this, but they are easier to write and use for the most common
        # cases
        # TODO: another ad-hoc implementation of Recurse-Up
        $i = $currentBlock
        $level = $scope - 1
        while ($level -gt 0 -and (any $i.Parent)) {
            $level--
            $i = $i.Parent
        }
        $block = $i
    }


    # we have our block so we need to collect all the history for the given mock

    $history = [System.Collections.Generic.List[Object]]@()
    $addToHistory = {
        param($b)
        $v = tryGetValue $b.PluginData.Mock.CallHistory $key
        if (any $v) {
            $history.Add($v)
        }
    }
    Fold-Block -Block $Block -OnBlock $addToHistory -OnTest $addToHistory

    if (0 -eq $history.Count) {
        # we did not find any calls, is the mock even defined?
        # TODO: should we look in the scope and the upper scopes for the mock or just assume 0 calls were done?
        return @{
            "$key" = @()
        }
    }


    return @{
        "$key" = @($history)
    }
}

function Get-MockDataForCurrentScope {
    [CmdletBinding()]
    param(
    )

    # this returns a mock table based on location, that we
    # then use to add the mock into, keep in mind that what we
    # pass must be a reference, so the data can be written in this
    # table

    $location = $currentTest = Get-CurrentTest
    $inTest = any $currentTest

    if (-not $inTest) {
        $location = $currentBlock = Get-CurrentBlock
    }

    if (none @($currentTest, $currentBlock)) {
        throw "I am neither in a test or a block, where am I?"
    }

    if (-not $location.PluginData.Mock) {
        throw "Mock data are not setup for this scope, what happened?"
    }

    if ($inTest) {
        Write-PesterDebugMessage -Scope Mock "We are in a test. Returning mock table from test scope."
    }
    else {
        Write-PesterDebugMessage -Scope Mock "We are in a block, one time setup or similar. Returning mock table from test block."
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

    # TODO: : figure out what mock table to use
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

        [string] $Scope = 0,
        [switch] $Exactly
    )

    # Assert-DescribeInProgress -CommandName Assert-MockCalled
    if ('Describe', 'Context', 'It' -notcontains $Scope -and $Scope -notmatch "^\d+$") {
        throw "Parameter Scope must be one of 'Describe', 'Context', 'It' or a non-negative number."
    }

    $SessionState = $PSCmdlet.SessionState

    $isNumericScope = $Scope -match "^\d+$"
    $currentTest = Get-CurrentTest
    $inTest = any $currentTest
    $currentBlock = Get-CurrentBlock

    $frame = if ($isNumericScope) {
        [PSCustomObject]@{
            Scope  = $Scope
            Frame  = if ($inTest) { $currentTest } else { $currentBlock }
            IsTest = $inTest
        }
    }
    else {
        if ($Scope -eq 'It') {
            if ($inTest) {
                [PSCustomObject]@{
                    Scope  = 0
                    Frame  = $currentTest
                    IsTest = $true
                }
            }
            else {
                throw "Assertion is placed outside of an It block, but -Scope It is specified."
            }
        }
        else {
            # we are not looking for an It scope, so we are looking for a block scope
            # blocks can be chained arbitrarily, so we need to walk up the tree looking
            # for the first match

            # TODO: this is ad-hoc implementation of folding the tree of parents
            # make the normal fold work better, and replace this
            $i = $currentBlock
            $level = 0
            while ($null -ne $i) {
                if ($Scope -eq $i.FrameworkData.CommandUsed) {
                    if ($inTest) {
                        # we are in a test but we looked up the scope based on the block
                        # so we need to add 1 to the scope, because the block is scope 1 for us
                        $level++
                    }

                    [PSCustomObject]@{
                        Scope  = $level
                        Frame  = if ($inTest) { $currentTest } else { $currentBlock }
                        IsTest = $inTest
                    }
                    break
                }
                $level++
                $i = $i.Parent
            }
        }
    }

    $contextInfo = Resolve-Command $CommandName $ModuleName -SessionState $SessionState
    $resolvedModule = tryGetProperty $contextInfo.Module Name
    $resolvedCommand = $contextInfo.Command.Name

    $mockTable = Get-AssertMockTable -Frame $frame -CommandName $resolvedCommand -ModuleName $resolvedModule

    tryRemoveKey $PSBoundParameters Scope
    tryRemoveKey $PSBoundParameters ModuleName
    tryRemoveKey $PSBoundParameters CommandName
    Assert-MockCalledInternal @PSBoundParameters `
        -ContextInfo $contextInfo `
        -MockTable $mockTable `
        -SessionState $SessionState
}

function Find-ClosestBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String] $CommandUsed
    )


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

    Invoke-MockInternal @PSBoundParameters -MockTable $mockTable -CallHistoryTable $callHistoryTable -SessionState $PSCmdlet.SessionState
}

function Assert-RunInProgress {
    param(
        [Parameter(Mandatory)]
        [String] $CommandName
    )

    if (Is-Discovery) {
        throw "$CommandName can run only during Run, but not during Discovery."
    }
}




