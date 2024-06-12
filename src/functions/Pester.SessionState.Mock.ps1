# session state bound functions that act as endpoints,
# so the internal functions can make their session state
# consumption explicit and are testable (also prevents scrolling past
# the whole documentation :D )

function Get-MockPlugin () {
    New-PluginObject -Name "Mock" `
        -ContainerRunStart {
        param($Context)

        $Context.Block.PluginData.Mock = @{
            Hooks       = [System.Collections.Generic.List[object]]@()
            CallHistory = @{}
            Behaviors   = @{}
        }
    } -EachBlockSetupStart {
        param($Context)
        $Context.Block.PluginData.Mock = @{
            Hooks       = [System.Collections.Generic.List[object]]@()
            CallHistory = @{}
            Behaviors   = @{}
        }
    } -EachTestSetupStart {
        param($Context)
        $Context.Test.PluginData.Mock = @{
            Hooks       = [System.Collections.Generic.List[object]]@()
            CallHistory = @{}
            Behaviors   = @{}
        }
    } -EachTestTeardownEnd {
        param($Context)
        # we are defining that table in the setup but the teardowns
        # need to be resilient, because they will run even if the setups
        # did not run
        # TODO: resolve this path safely
        $hooks = $Context.Test.PluginData.Mock.Hooks
        Remove-MockHook -Hooks $hooks
    } -EachBlockTeardownEnd {
        param($Context)
        # TODO: resolve this path safely
        $hooks = $Context.Block.PluginData.Mock.Hooks
        Remove-MockHook -Hooks $hooks
    } -ContainerRunEnd {
        param($Context)
        # TODO: resolve this path safely
        $hooks = $Context.Block.PluginData.Mock.Hooks
        Remove-MockHook -Hooks $hooks
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

    Mocks can be marked Verifiable. If so, the Should -InvokeVerifiable command
    can be used to check if all Verifiable mocks were actually called. If any
    verifiable mock is not called, Should -InvokeVerifiable will throw an
    exception and indicate all mocks not called.

    If you wish to mock commands that are called from inside a script or manifest
    module, you can do so by using the -ModuleName parameter to the Mock command.
    This injects the mock into the specified module. If you do not specify a
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
    When this is set, the mock will be checked when Should -InvokeVerifiable is
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

    .PARAMETER RemoveParameterType
    Optional list of parameter names that should use Object as the parameter
    type instead of the parameter type defined by the function. This relaxes the
    type requirements and allows some strongly typed functions to be mocked
    more easily.

    .PARAMETER RemoveParameterValidation
    Optional list of parameter names in the original command
    that should not have any validation rules applied. This relaxes the
    validation requirements, and allows functions that are strict about their
    parameter validation to be mocked more easily.

    .EXAMPLE
    Mock Get-ChildItem { return @{FullName = "A_File.TXT"} }

    Using this Mock, all calls to Get-ChildItem will return a hashtable with a FullName property returning "A_File.TXT"

    .EXAMPLE
    Mock Get-ChildItem { return @{FullName = "A_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp) }

    This Mock will only be applied to Get-ChildItem calls within the user's temp directory.

    .EXAMPLE
    Mock Set-Content {} -Verifiable -ParameterFilter { $Path -eq "some_path" -and $Value -eq "Expected Value" }

    When this mock is used, if the Mock is never invoked and Should -InvokeVerifiable is called, an exception will be thrown. The command behavior will do nothing since the ScriptBlock is empty.

    .EXAMPLE
    ```powershell
    Mock Get-ChildItem { return @{FullName = "A_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp\1) }
    Mock Get-ChildItem { return @{FullName = "B_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp\2) }
    Mock Get-ChildItem { return @{FullName = "C_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp\3) }
    ```

    Multiple mocks of the same command may be used. The parameter filter determines which is invoked. Here, if Get-ChildItem is called on the "2" directory of the temp folder, then B_File.txt will be returned.

    .EXAMPLE
    ```powershell
    Mock Get-ChildItem { return @{FullName="B_File.TXT"} } -ParameterFilter { $Path -eq "$env:temp\me" }
    Mock Get-ChildItem { return @{FullName="A_File.TXT"} } -ParameterFilter { $Path -and $Path.StartsWith($env:temp) }

    Get-ChildItem $env:temp\me
    ```

    Here, both mocks could apply since both filters will pass. A_File.TXT will be returned because it was the most recent Mock created.

    .EXAMPLE
    ```powershell
    Mock Get-ChildItem { return @{FullName = "B_File.TXT"} } -ParameterFilter { $Path -eq "$env:temp\me" }
    Mock Get-ChildItem { return @{FullName = "A_File.TXT"} }

    Get-ChildItem c:\windows
    ```

    Here, A_File.TXT will be returned. Since no filter was specified, it will apply to any call to Get-ChildItem that does not pass another filter.

    .EXAMPLE
    ```powershell
    Mock Get-ChildItem { return @{FullName = "B_File.TXT"} } -ParameterFilter { $Path -eq "$env:temp\me" }
    Mock Get-ChildItem { return @{FullName = "A_File.TXT"} }

    Get-ChildItem $env:temp\me
    ```

    Here, B_File.TXT will be returned. Even though the filterless mock was created more recently. This illustrates that filterless Mocks are always evaluated last regardless of their creation order.

    .EXAMPLE
    Mock Get-ChildItem { return @{FullName = "A_File.TXT"} } -ModuleName MyTestModule

    Using this Mock, all calls to Get-ChildItem from within the MyTestModule module
    will return a hashtable with a FullName property returning "A_File.TXT"

    .EXAMPLE
    ```powershell
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
    ```

    This example shows how calls to commands made from inside a module can be
    mocked by using the -ModuleName parameter.

    .LINK
    https://pester.dev/docs/commands/Mock

    .LINK
    https://pester.dev/docs/usage/mocking
    #>
    [CmdletBinding()]
    param(
        [string]$CommandName,
        [ScriptBlock]$MockWith = {},
        [switch]$Verifiable,
        [ScriptBlock]$ParameterFilter,
        [string]$ModuleName,
        [string[]]$RemoveParameterType,
        [string[]]$RemoveParameterValidation
    )
    if (Is-Discovery) {
        # this is to allow mocks in between Describe and It which is discouraged but common
        # and will make for an easier move to v5
        return
    }

    $SessionState = $PSCmdlet.SessionState

    # use the caller module name as ModuleName, so calling the mock in InModuleScope uses the ModuleName as target module
    if (-not $PSBoundParameters.ContainsKey('ModuleName') -and $null -ne $SessionState.Module) {
        $ModuleName = $SessionState.Module.Name
    }

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Mock -Message "Setting up $(if ($ParameterFilter) {"parametrized"} else {"default"}) mock for$(if ($ModuleName) {" $ModuleName -"}) $CommandName."
    }


    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        $null = Set-ScriptBlockHint -Hint "Unbound MockWith - Captured in Mock" -ScriptBlock $MockWith
        $null = if ($ParameterFilter) { Set-ScriptBlockHint -Hint "Unbound ParameterFilter - Captured in Mock" -ScriptBlock $ParameterFilter }
    }

    # takes 0.4 ms max
    $invokeMockCallBack = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Invoke-Mock', 'function')

    $mockData = Get-MockDataForCurrentScope
    $contextInfo = Resolve-Command $CommandName $ModuleName -SessionState $SessionState

    if ($contextInfo.IsMockBootstrapFunction) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Mock -Message "Mock resolves to an existing hook, will only define mock behavior."
        }
        $hook = $contextInfo.Hook
    }
    else {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Mock -Message "Mock does not have a hook yet, creating a new one."
        }
        $hook = Create-MockHook -ContextInfo $contextInfo -InvokeMockCallback $invokeMockCallBack
        $mockData.Hooks.Add($hook)
    }

    if ($mockData.Behaviors.ContainsKey($contextInfo.Command.Name)) {
        $behaviors = $mockData.Behaviors[$contextInfo.Command.Name]
    }
    else {
        $behaviors = [System.Collections.Generic.List[Object]]@()
        $mockData.Behaviors[$contextInfo.Command.Name] = $behaviors
    }

    $behavior = New-MockBehavior -ContextInfo $contextInfo -MockWith $MockWith -Verifiable:$Verifiable -ParameterFilter $ParameterFilter -Hook $hook
    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Mock -Message "Adding a new $(if ($behavior.IsDefault) {"default"} else {"parametrized"}) behavior to $(if ($behavior.ModuleName) { "$($behavior.ModuleName) - "})$($behavior.CommandName)."
    }
    $behaviors.Add($behavior)
}

function Get-AllMockBehaviors {
    param(
        [Parameter(Mandatory)]
        [String] $CommandName
    )
    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Mock "Getting all defined mock behaviors in this and parent scopes for command $CommandName."
    }
    # this is used for invoking mocks
    # in there we care about all mocks attached to the current test
    # or any of the mocks above it
    # this does not list mocks in other tests
    $currentTest = Get-CurrentTest
    $inTest = $null -ne $currentTest

    $behaviors = [System.Collections.Generic.List[Object]]@()
    if ($inTest) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Mock "We are in a test. Finding all behaviors in this test."
        }
        $bs = @(if ($currentTest.PluginData.Mock.Behaviors.ContainsKey($CommandName)) {
                $currentTest.PluginData.Mock.Behaviors.$CommandName
            })
        if ($null -ne $bs -and $bs.Count -gt 0) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Mock "Found behaviors for '$CommandName' in the test."
            }
            $bss = @(for ($i = $bs.Count - 1; $i -ge 0; $i--) { $bs[$i] })
            $behaviors.AddRange($bss)
        }
        else {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Mock "Found no behaviors for '$CommandName' in this test."
            }
        }
    }
    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Mock "Finding all behaviors in this block and parent blocks."
    }
    $block = Get-CurrentBlock

    # recurse up
    $behaviorsInTestCount = $behaviors.Count
    while ($null -ne $block) {

        # action
        $bs = @(if ($block.PluginData.Mock.Behaviors.ContainsKey($CommandName)) {
                $block.PluginData.Mock.Behaviors.$CommandName
            })

        if ($null -ne $bs -and 0 -lt @($bs).Count) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Mock "Found behaviors for '$CommandName' in '$($block.Name)'."
            }
            $bss = @(for ($i = $bs.Count - 1; $i -ge 0; $i--) { $bs[$i] })
            $behaviors.AddRange($bss)
        }
        # action end

        $block = $block.Parent
    }

    if ($PesterPreference.Debug.WriteDebugMessages.Value -and $behaviorsInTestCount -eq $behaviors.Count) {
        Write-PesterDebugMessage -Scope Mock "Found $($behaviors.Count - $behaviorsInTestCount) behaviors in all parent blocks, and $behaviorsInTestCount behaviors in test."
    }

    $behaviors
}

function Get-VerifiableBehaviors {
    [CmdletBinding()]
    param(
    )
    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Mock "Getting all verifiable mock behaviors in this scope."
    }

    $currentTest = Get-CurrentTest
    $inTest = $null -ne $currentTest

    $behaviors = [System.Collections.Generic.List[Object]]@()
    if ($inTest) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Mock "We are in a test. Finding all behaviors in this test."
        }
        $allBehaviors = $currentTest.PluginData.Mock.Behaviors.Values
        if ($null -ne $allBehaviors -and $allBehaviors.Count -gt 0) {
            # all behaviors for all commands
            foreach ($commandBehaviors in $allBehaviors) {
                if ($null -ne $commandBehaviors -and $commandBehaviors.Count -gt 0) {
                    # all behaviors for single command
                    foreach ($behavior in $commandBehaviors) {
                        if ($behavior.Verifiable) {
                            $behaviors.Add($behavior)
                        }
                    }
                }
            }
        }
    }
    $block = Get-CurrentBlock

    # recurse up
    while ($null -ne $block) {

        ## action
        $allBehaviors = $block.PluginData.Mock.Behaviors.Values
        # all behaviors for all commands
        if ($null -ne $allBehaviors -or $allBehaviors.Count -ne 0) {
            foreach ($commandBehaviors in $allBehaviors) {
                if ($null -ne $commandBehaviors -and $commandBehaviors.Count -gt 0) {
                    # all behaviors for single command
                    foreach ($behavior in $commandBehaviors) {
                        if ($behavior.Verifiable) {
                            $behaviors.Add($behavior)
                        }
                    }
                }
            }
        }

        # end action
        $block = $block.Parent
    }
    # end

    $behaviors
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

    $key = "$ModuleName||$CommandName"
    $scope = $Frame.Scope
    $inTest = $Frame.IsTest
    # this is used for assertions, in here we need to collect
    # all call histories for the given command in the scope.
    # if the scope number is bigger than 0 then we need all
    # in the whole scope including all its

    if ($inTest -and 0 -eq $scope) {
        # we are in test and we care only about the test scope,
        # this is easy, we just look for call history of the command


        $history = if ($Frame.Frame.PluginData.Mock.CallHistory.ContainsKey($Key)) {
            # do not enumerate so we get the same thing back
            # even if it is a collection
            $Frame.Frame.PluginData.Mock.CallHistory.$Key
        }

        if ($history) {
            return @{
                "$key" = [Collections.Generic.List[object]]@($history)
            }
        }
        else {
            return @{
                "$key" = [Collections.Generic.List[object]]@()
            }

            # TODO: This figures out if the mock was defined, when there  were 0 calls, it adds overhead
            # and does not work with the current layout of hooks and history
            # $test = $Frame.Frame
            # $mockInTest = tryGetValue $test.PluginData.Mock.Hooks $key
            # if ($mockInTest) {
            #     # the mock was defined in it but it was not called in this scope
            #     return @{
            #         "$key" = @()
            #     }
            # }
            # else {
            #     # try finding the mock definition in upper scopes, because it was not found in the current test
            #     $mockInBlock = Recurse-Up $test.Block {
            #         param ($b)
            #         if ((tryGetProperty $b.PluginData Mock) -and (tryGetProperty $b.PluginData.Mock Hooks)) {
            #             tryGetValue $b.PluginData.Mock.Hooks $key
            #         }
            #     }

            #     if (none $mockInBlock) {
            #         throw "Could not find any mock definition for $CommandName$(if ($ModuleName) { " from module $ModuleName"})."
            #     }
            #     else {
            #         # the mock was defined in some upper scope but it was not called in this it
            #         return @{
            #             "$key" = @()
            #         }
            #     }
            #}
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
    elseif ($scope -eq 1) {
        # in scope 1 it is the parent
        $block = if ($null -ne $currentBlock.Parent) { $currentBlock.Parent } else { $currentBlock }
    }
    else {
        # otherwise we just walk up as many scopes as needed until
        # we reach the desired scope, or the root of the tree, the above ifs could
        # be replaced by this, but they are easier to write and use for the most common
        # cases
        $i = $currentBlock
        $level = $scope - 1
        while ($level -ge 0 -and ($null -ne $i.Parent)) {
            $level--
            $i = $i.Parent
        }
        $block = $i
    }


    # we have our block so we need to collect all the history for the given mock

    $history = [System.Collections.Generic.List[Object]]@()
    $addToHistory = {
        param($b)

        if (-not $b.pluginData.ContainsKey('Mock')) {
            return
        }

        $mockData = $b.pluginData.Mock

        $callHistory = $mockData.CallHistory


        $v = if ($callHistory.ContainsKey($key)) {
            $callHistory.$key
        }

        if ($null -ne $v -and 0 -ne $v.Count) {
            $history.AddRange([System.Collections.Generic.List[Object]]@($v))
        }
    }

    Fold-Block -Block $Block -OnBlock $addToHistory -OnTest $addToHistory
    if (0 -eq $history.Count) {
        # we did not find any calls, is the mock even defined?
        # TODO: should we look in the scope and the upper scopes for the mock or just assume 0 calls were done?
        return @{
            "$key" = [Collections.Generic.List[object]]@()
        }
    }


    return @{
        "$key" = [Collections.Generic.List[object]]@($history)
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
    $inTest = $null -ne $currentTest

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
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Mock "We are in a test. Returning mock table from test scope."
        }
    }
    else {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Mock "We are in a block, one time setup or similar. Returning mock table from test block."
        }
    }

    $location.PluginData.Mock
}

function Should-InvokeVerifiable ([switch] $Negate, [string] $Because) {
    <#
    .SYNOPSIS
    Checks if any Verifiable Mock has not been invoked. If so, this will throw an exception.

    .DESCRIPTION
    This can be used in tandem with the -Verifiable switch of the Mock
    function. Mock can be used to mock the behavior of an existing command
    and optionally take a -Verifiable switch. When Should -InvokeVerifiable
    is called, it checks to see if any Mock marked Verifiable has not been
    invoked. If any mocks have been found that specified -Verifiable and
    have not been invoked, an exception will be thrown.

    .EXAMPLE
    Mock Set-Content {} -Verifiable -ParameterFilter {$Path -eq "some_path" -and $Value -eq "Expected Value"}

    { ...some code that never calls Set-Content some_path -Value "Expected Value"... }

    Should -InvokeVerifiable

    This will throw an exception and cause the test to fail.

    .EXAMPLE
    Mock Set-Content {} -Verifiable -ParameterFilter {$Path -eq "some_path" -and $Value -eq "Expected Value"}

    Set-Content some_path -Value "Expected Value"

    Should -InvokeVerifiable

    This will not throw an exception because the mock was invoked.
    #>
    $behaviors = @(Get-VerifiableBehaviors)
    Should-InvokeVerifiableInternal @PSBoundParameters -Behaviors $behaviors
}

& $script:SafeCommands['Add-ShouldOperator'] -Name InvokeVerifiable `
    -InternalName Should-InvokeVerifiable `
    -Test         ${function:Should-InvokeVerifiable}

Set-ShouldOperatorHelpMessage -OperatorName InvokeVerifiable `
    -HelpMessage 'Checks if any Verifiable Mock has not been invoked. If so, this will throw an exception.'

function Should-Invoke {
    <#
    .SYNOPSIS
    Checks if a Mocked command has been called a certain number of times
    and throws an exception if it has not.

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
    #>
    [CmdletBinding(DefaultParameterSetName = 'ParameterFilter')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$CommandName,

        [Parameter(Position = 1)]
        [int]$Times = 1,

        [ScriptBlock]$ParameterFilter = { $True },

        [Parameter(ParameterSetName = 'ExclusiveFilter', Mandatory = $true)]
        [scriptblock] $ExclusiveFilter,

        [string] $ModuleName,
        [string] $Scope = 0,
        [switch] $Exactly,

        # built-in variables
        [object] $ActualValue,
        [switch] $Negate,
        [string] $Because,
        [Management.Automation.SessionState] $CallerSessionState
    )

    if ($null -ne $ActualValue) {
        throw "Should -Invoke does not take pipeline input or ActualValue."
    }

    # Assert-DescribeInProgress -CommandName Should -Invoke
    if ('Describe', 'Context', 'It' -notcontains $Scope -and $Scope -notmatch "^\d+$") {
        throw "Parameter Scope must be one of 'Describe', 'Context', 'It' or a non-negative number."
    }

    if (-not $PSBoundParameters.ContainsKey("ModuleName")) {
        # user did not specify the target module, using the caller session state module name
        # to ensure we bind to the current module when running in InModuleScope
        $ModuleName = if ($CallerSessionState.Module) { $CallerSessionState.Module.Name } else { $null }
    }

    if ($PSCmdlet.ParameterSetName -eq 'ExclusiveFilter' -and $Negate) {
        # Using -Not with -ExclusiveFilter makes for a very confusing expectation. For example, given the following mocked function:
        #
        # Mock FunctionUnderTest {}
        #
        # Consider the normal expectation:
        # `Should -Invoke FunctionUnderTest -ExclusiveFilter { $param1 -eq 'one' }`
        #
        # | Invocations               | Should raises an error |
        # | --------------------------| ---------------------- |
        # | FunctionUnderTest "one"   | No                     |
        # | --------------------------| ---------------------- |
        # | FunctionUnderTest "one"   | Yes                    |
        # | FunctionUnderTest "two"   |                        |
        # | --------------------------| ---------------------- |
        # | FunctionUnderTest "two"   | Yes                    |
        #
        # So it follows that if we negate that, using -Not, then we should get the opposite result. That is:
        #
        # `Should -Not -Invoke FunctionUnderTest -ExclusiveFilter { $param1 -eq 'one' }`
        #
        # | Invocations               | Should raises an error |
        # | --------------------------| ---------------------- |
        # | FunctionUnderTest "one"   | Yes                    |
        # | --------------------------| ---------------------- |
        # | FunctionUnderTest "one"   | No                     | <---- Problem!
        # | FunctionUnderTest "two"   |                        |
        # | --------------------------| ---------------------- |
        # | FunctionUnderTest "two"   | No                     |
        #
        # The problem is the second row. Because there was an invocation of `{ $param1 -eq 'one' }` the
        # expectation is not met and Should should raise an error.
        #
        # In fact it can be shown that
        #
        # `Should -Not -Invoke FunctionUnderTest -ExclusiveFilter { ... }`
        #
        # and
        #
        # `Should -Not -Invoke FunctionUnderTest -ParameterFilter { ... }`
        #
        # have the same result.
        throw "Cannot use -ExclusiveFilter when -Not is specified. Use -ParameterFilter instead."
    }

    $isNumericScope = $Scope -match "^\d+$"
    $currentTest = Get-CurrentTest
    $inTest = $null -ne $currentTest
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

            if ($null -eq $i) {
                # Reached parent of root-block which means we never called break (got a hit) in the while-loop
                throw "Assertion is not placed directly nor nested inside a $Scope block, but -Scope $Scope is specified."
            }
        }
    }

    $SessionState = $CallerSessionState
    # This resolve happens only because we need to resolve from an alias to the real command
    # name, and we cannot know what all aliases are there for a command in the module, easily,
    # we could short circuit this resolve when we find history, and only resolve if we don't
    # have any history. We could also keep info about the alias from which we originally
    # resolved the command, which would give us another piece of info. But without scanning
    # all the aliases in the module we won't be able to get rid of this, but that would be
    # cost we would have to pay all the time, instead of just doing extra resolve when we find
    # no history.
    $contextInfo = Resolve-Command $CommandName $ModuleName -SessionState $SessionState
    if ($null -eq $contextInfo.Hook) {
        throw "Should -Invoke: Could not find Mock for command $CommandName in $(if ([string]::IsNullOrEmpty($ModuleName)){ "script scope" } else { "module $ModuleName" }). Was the mock defined? Did you use the same -ModuleName as on the Mock? When using InModuleScope are InModuleScope, Mock and Should -Invoke using the same -ModuleName?"
    }
    $resolvedModule = $contextInfo.TargetModule
    $resolvedCommand = $contextInfo.Command.Name

    $mockTable = Get-AssertMockTable -Frame $frame -CommandName $resolvedCommand -ModuleName $resolvedModule

    if ($PSBoundParameters.ContainsKey('Scope')) {
        $PSBoundParameters.Remove('Scope')
    }
    if ($PSBoundParameters.ContainsKey('ModuleName')) {
        $PSBoundParameters.Remove('ModuleName')
    }
    if ($PSBoundParameters.ContainsKey('CommandName')) {
        $PSBoundParameters.Remove('CommandName')
    }
    if ($PSBoundParameters.ContainsKey('ActualValue')) {
        $PSBoundParameters.Remove('ActualValue')
    }
    if ($PSBoundParameters.ContainsKey('CallerSessionState')) {
        $PSBoundParameters.Remove('CallerSessionState')
    }

    $result = Should-InvokeInternal @PSBoundParameters `
        -ContextInfo $contextInfo `
        -MockTable $mockTable `
        -SessionState $SessionState

    return $result
}

& $script:SafeCommands['Add-ShouldOperator'] -Name Invoke `
    -InternalName Should-Invoke `
    -Test         ${function:Should-Invoke}

Set-ShouldOperatorHelpMessage -OperatorName Invoke `
    -HelpMessage 'Checks if a Mocked command has been called a certain number of times and throws an exception if it has not.'

function Invoke-Mock {
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

        [object] $InputObject,

        $Hook
    )

    if ('End' -eq $FromBlock) {
        if (-not $MockCallState.ShouldExecuteOriginalCommand) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope MockCore "Mock for $CommandName was invoked from block $FromBlock, and should not execute the original command, returning."
            }
            return
        }
        else {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope MockCore "Mock for $CommandName was invoked from block $FromBlock, and should execute the original command, forwarding the call to Invoke-MockInternal without call history and without behaviors."
            }
            Invoke-MockInternal @PSBoundParameters -Behaviors @() -CallHistory @{}
            return
        }
    }

    if ('Begin' -eq $FromBlock) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope MockCore "Mock for $CommandName was invoked from block $FromBlock, and should execute the original command, Invoke-MockInternal without call history and without behaviors."
        }
        Invoke-MockInternal @PSBoundParameters -Behaviors @() -CallHistory @{}
        return
    }

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Mock "Mock for $CommandName was invoked from block $FromBlock, resolving call history and behaviors."
    }

    # this function is called by the mock bootstrap function, so every implementer
    # should implement this (but I keep it separate from the core function so I can
    # test without dependency on scopes)
    $allBehaviors = Get-AllMockBehaviors -CommandName $CommandName

    # there is some conflict that keeps ModuleName constant without throwing. It is not a problem
    # because it does not contain whitespace, but if someone mistypes we won't be able to fix it
    # to be empty string in the below condition.
    $TargetModule = $ModuleName
    $targettingAModule = -not [string]::IsNullOrWhiteSpace($TargetModule)

    $getBehaviorMessage = if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        # output scriptblock that we can call later
        {
            param ($b)
            "     Target module: $(if ($b.ModuleName) { $b.ModuleName } else { '$null' })`n"
            "    Body: { $($b.ScriptBlock.ToString().Trim()) }`n"
            "    Filter: $(if (-not $b.IsDefault) { "{ $($b.Filter.ToString().Trim()) }" } else { '$null' })`n"
            "    Default: $(if ($b.IsDefault) { '$true' } else { '$false' })`n"
            "    Verifiable: $(if ($b.Verifiable) { '$true' } else { '$false' })"
        }
    }

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Mock -Message "Filtering behaviors for command $CommandName, for target module $(if ($targettingAModule) { $TargetModule } else { '$null' }) (Showing all behaviors for this command, actual filtered list is further in the log, look for 'Filtered parametrized behaviors:' and 'Filtered default behaviors:'):"
    }

    $moduleBehaviors = [System.Collections.Generic.List[Object]]@()
    $moduleDefaultBehavior = $null
    $nonModuleBehaviors = [System.Collections.Generic.List[Object]]@()
    $nonModuleDefaultBehavior = $null
    foreach ($b in $allBehaviors) {
        # sort behaviors into filtered and default behaviors for the targeted module
        # other modules and no-modules. The behaviors for other modules we don't care about so we
        # don't collect them. For the behaviors for the target module and no module we split them
        # to filtered and default. When we target a module mock, we select the filtered + the most recent default, but when
        # there is no default we take the most recent default from non-module behaviors, to allow fallback to it, because that is
        # how it was historically done, and makes it a bit more safe.
        if ($b.IsInModule) {
            if ($TargetModule -eq $b.ModuleName) {
                if ($b.IsDefault) {
                    # keep the first found (the last one defined)
                    if ($null -eq $moduleDefaultBehavior) {
                        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                            Write-PesterDebugMessage -Scope Mock -Message "Behavior is a default behavior from the target module $TargetModule, saving it:`n$(& $getBehaviorMessage $b)"
                        }
                        $moduleDefaultBehavior = $b
                    }
                    else {
                        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                            Write-PesterDebugMessage -Scope Mock -Message "Behavior is a default behavior from the target module $TargetModule, but we already have one that was defined more recently it, skipping it:`n$(& $getBehaviorMessage $b)"
                        }
                    }
                }
                else {
                    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                        Write-PesterDebugMessage -Scope Mock -Message "Behavior is a parametrized behavior from the target module $TargetModule, adding it to parametrized behavior list:`n$(& $getBehaviorMessage $b)"
                    }
                    $moduleBehaviors.Add($b)
                }
            }
            else {
                # not the targeted module, skip it
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Mock -Message "Behavior is not from the target module $(if ($targettingAModule) { $TargetModule } else { '$null' }), skipping it:`n$(& $getBehaviorMessage $b)"
                }
            }
        }
        else {
            if ($b.IsDefault) {
                # keep the first found (the last one defined)
                if ($null -eq $nonModuleDefaultBehavior) {
                    $nonModuleDefaultBehavior = $b
                    if ($targettingAModule -and $PesterPreference.Debug.WriteDebugMessages.Value) {
                        Write-PesterDebugMessage -Scope Mock -Message "Behavior is a default behavior from script scope, saving it to use as a fallback if default behavior for module $TargetModule is not found:`n$(& $getBehaviorMessage $b)"
                    }

                    if (-not $targettingAModule -and $PesterPreference.Debug.WriteDebugMessages.Value) {
                        Write-PesterDebugMessage -Scope Mock -Message "Behavior is a default behavior from script scope, saving it:`n$(& $getBehaviorMessage $b)"
                    }
                }
                else {
                    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                        Write-PesterDebugMessage -Scope Mock -Message "Behavior is a default behavior from script scope, but we already have one that was defined more recently it, skipping it:`n$(& $getBehaviorMessage $b)"
                    }
                }
            }
            else {
                if ($targettingAModule -and $PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Mock -Message "Behavior is a parametrized behavior from script scope, skipping it. (Parametrized script scope behaviors are not used as fallback for module scoped mocks.):`n$(& $getBehaviorMessage $b)"
                }

                if (-not $targettingAModule -and $PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Mock -Message "Behavior is a parametrized behavior from script scope, adding it to non-module parametrized behavior list:`n$(& $getBehaviorMessage $b)"
                }

                $nonModuleBehaviors.Add($b)
            }
        }
    }

    # if we are targeting a module use the behaviors for the current module, but if there is no default the fall back to the non-module default behavior.
    # do not fallback to non-module filtered behaviors. This is here for safety, and for compatibility when doing Mock Remove-Item {}, and then mocking in module
    # then the default mock for Remove-Item should be effective.

    # using @() to always get array. This avoids null error in Invoke-MockInternal when no behaviors where found (if-else unwraps the lists)
    $behaviors = @(if ($targettingAModule) {
        # we have default module behavior add it to the filtered behaviors if there are any
        if ($null -ne $moduleDefaultBehavior) {
            $moduleBehaviors.Add($moduleDefaultBehavior)
        }
        else {
            # we don't have default module behavior add the default non-module behavior if we have any
            if ($null -ne $nonModuleDefaultBehavior) {
                $moduleBehaviors.Add($nonModuleDefaultBehavior)
            }
        }

        $moduleBehaviors
    }
    else {
        # we are not targeting a mock in a module use the non module behaviors
        if ($null -ne $nonModuleDefaultBehavior) {
            # add the default non-module behavior if we have any
            $nonModuleBehaviors.Add($nonModuleDefaultBehavior)
        }

        $nonModuleBehaviors
    })

    $callHistory = (Get-MockDataForCurrentScope).CallHistory

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        $any = $false
        $message = foreach ($b in $behaviors) {
            if (-not $b.IsDefault) {
                $any = $true
                & $getBehaviorMessage $b
            }
        }
        if (-not $any) {
            $message = '$null'
        }
        Write-PesterDebugMessage -Scope Mock -Message "Filtered parametrized behaviors:`n$message"

        $default = foreach ($b in $behaviors) {
            if ($b.IsDefault) {
                $b
                break
            }
        }
        $message = if ($null -ne $default) { & $getBehaviorMessage $b } else { '$null' }
        $fallBack = if ($null -ne $default -and $targettingAModule -and [string]::IsNullOrEmpty($b.ModuleName) ) { " (fallback to script scope default behavior)" } else { $null }
        Write-PesterDebugMessage -Scope Mock -Message "Filtered default behavior$($fallBack):`n$message"
    }

    Invoke-MockInternal @PSBoundParameters -Behaviors $behaviors -CallHistory $callHistory
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



