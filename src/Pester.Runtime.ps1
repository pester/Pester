# PESTER_BUILD
if (-not (Get-Variable -Name "PESTER_BUILD" -ValueOnly -ErrorAction Ignore)) {
    . "$PSScriptRoot/Pester.Utility.ps1"
    . "$PSScriptRoot/functions/Pester.SafeCommands.ps1"
    . "$PSScriptRoot/Pester.Types.ps1"

    if ($null -eq $PesterPreference) {
        $PesterPreference = [PesterConfiguration]::Default
    }
}
else {
    if ($null -eq $PesterPreference) {
        $PesterPreference = [PesterConfiguration]::Default
    }
}
# end PESTER_BUILD

# interesting commands
# # the core stuff I am mostly sure about
# 'New-PesterState'
# 'New-Block'
# 'New-ParametrizedBlock'
# 'New-Test'
# 'New-ParametrizedTest'
# 'New-EachTestSetup'
# 'New-EachTestTeardown'
# 'New-OneTimeTestSetup'
# 'New-OneTimeTestTeardown'
# 'New-EachBlockSetup'
# 'New-EachBlockTeardown'
# 'New-OneTimeBlockSetup'
# 'New-OneTimeBlockTeardown'
# 'Invoke-Test',
# 'Find-Test',
# 'Invoke-PluginStep'

# # here I have doubts if that is too much to expose
# 'Get-CurrentTest'
# 'Get-CurrentBlock'
# 'Is-Discovery'

# # those need to be refined and probably wrapped to something
# # that is like an object builder
# 'New-FilterObject'
# 'New-PluginObject'
# 'New-BlockContainerObject'


# instances
$flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
$script:SessionStateInternalProperty = [System.Management.Automation.SessionState].GetProperty('Internal', $flags)
$script:ScriptBlockSessionStateInternalProperty = [System.Management.Automation.ScriptBlock].GetProperty('SessionStateInternal', $flags)
$script:ScriptBlockSessionStateProperty = [System.Management.Automation.ScriptBlock].GetProperty("SessionState", $flags)

if (notDefined PesterPreference) {
    $PesterPreference = [PesterConfiguration]::Default
}
else {
    $PesterPreference = [PesterConfiguration] $PesterPreference
}

function New-PesterState {
    $o = [PSCustomObject] @{
        # indicate whether or not we are currently
        # running in discovery mode se we can change
        # behavior of the commands appropriately
        Discovery           = $false

        CurrentBlock        = $null
        CurrentTest         = $null

        Plugin              = $null
        PluginConfiguration = $null
        PluginData          = $null
        Configuration       = $null

        TotalStopWatch      = [Diagnostics.Stopwatch]::StartNew()
        UserCodeStopWatch   = [Diagnostics.Stopwatch]::StartNew()
        FrameworkStopWatch  = [Diagnostics.Stopwatch]::StartNew()

        Stack               = [Collections.Stack]@()
    }

    $o.TotalStopWatch.Restart()
    $o.FrameworkStopWatch.Restart()
    # user code stopwatch should not be running
    # because we are not in user code
    $o.UserCodeStopWatch.Reset()

    return $o
}

function Reset-PerContainerState {
    param(
        [Parameter(Mandatory = $true)]
        $RootBlock
    )
    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Runtime "Resetting per container state."
    }
    $state.CurrentBlock = $RootBlock
    $state.Stack.Clear()
}

function Find-Test {
    [OutputType([Pester.Container])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSObject[]] $BlockContainer,
        $Filter,
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState
    )

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope DiscoveryCore "Running just discovery."
    }

    # define the state if we don't have it yet, this will happen when we call this function directly
    # but normally the parent invoker (most often Invoke-Pester) will set the state. So we don't want to reset
    # it here.
    if (notDefined state) {
        $state = New-PesterState
    }

    $found = Discover-Test -BlockContainer $BlockContainer -Filter $Filter -SessionState $SessionState

    foreach ($f in $found) {
        ConvertTo-DiscoveredBlockContainer -Block $f
    }
}

function ConvertTo-DiscoveredBlockContainer {
    [OutputType([Pester.Container])]
    param (
        [Parameter(Mandatory = $true)]
        $Block
    )

    $b = [Pester.Container]::CreateFromBlock($Block)
    $b
}

function ConvertTo-ExecutedBlockContainer {
    [OutputType([Pester.Container])]
    param (
        [Parameter(Mandatory = $true)]
        $Block
    )

    foreach ($b in $Block) {
        [Pester.Container]::CreateFromBlock($b)
    }
}

function New-ParametrizedBlock {
    param (
        [Parameter(Mandatory = $true)]
        [String] $Name,
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock,
        [int] $StartLine = $MyInvocation.ScriptLineNumber,
        [int] $StartColumn = $MyInvocation.OffsetInLine,
        [String[]] $Tag = @(),
        [HashTable] $FrameworkData = @{ },
        [Switch] $Focus,
        [Switch] $Skip,
        $Data
    )

    # using the position of Describe/Context as Id to group data-generated blocks. Should be unique enough because it only needs to be unique for the current block
    # TODO: Id is used by NUnit2.5 and 3 testresults to group. A better way to solve this?
    $groupId = "${StartLine}:${StartColumn}"

    foreach ($d in @($Data)) {
        # shallow clone to give every block it's own copy
        $fmwData = $FrameworkData.Clone()
        New-Block -GroupId $groupId -Name $Name -ScriptBlock $ScriptBlock -StartLine $StartLine -Tag $Tag -FrameworkData $fmwData -Focus:$Focus -Skip:$Skip -Data $d
    }
}

# endpoint for adding a block that contains tests
# or other blocks
function New-Block {
    param (
        [Parameter(Mandatory = $true)]
        [String] $Name,
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock,
        [int] $StartLine = $MyInvocation.ScriptLineNumber,
        [String[]] $Tag = @(),
        [HashTable] $FrameworkData = @{ },
        [Switch] $Focus,
        [String] $GroupId,
        [Switch] $Skip,
        $Data
    )

    # Switch-Timer -Scope Framework
    # $overheadStartTime = $state.FrameworkStopWatch.Elapsed
    # $blockStartTime = $state.UserCodeStopWatch.Elapsed

    $state.Stack.Push($Name)
    $path = @( <# Get full name #> $history = $state.Stack.ToArray(); [Array]::Reverse($history); $history)
    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Runtime "Entering path $($path -join '.')"
    }

    $block = $null
    $previousBlock = $state.CurrentBlock

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope DiscoveryCore "Adding block $Name to discovered blocks"
    }

    # new block
    $block = [Pester.Block]::Create()
    $block.Name = $Name
    # using the non-expanded name as default to fallback to it if we don't
    # reach the point where we expand it, for example because of setup failure
    $block.ExpandedName = $Name

    $block.Path = $Path
    # using the non-expanded path as default to fallback to it if we don't
    # reach the point where we expand it, for example because of setup failure
    $block.ExpandedPath = $Path -join '.'
    $block.Tag = $Tag
    $block.ScriptBlock = $ScriptBlock
    $block.StartLine = $StartLine
    $block.FrameworkData = $FrameworkData
    $block.Focus = $Focus
    $block.GroupId = $GroupId
    $block.Skip = $Skip
    $block.Data = $Data

    # we attach the current block to the parent, and put it to the parent
    # lists
    $block.Parent = $state.CurrentBlock
    $state.CurrentBlock.Order.Add($block)
    $state.CurrentBlock.Blocks.Add($block)

    # and then make it the new current block
    $state.CurrentBlock = $block
    try {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope DiscoveryCore "Discovering in body of block $Name"
        }

        if ($null -ne $block.Data) {
            $context = @{}
            Add-DataToContext -Destination $context -Data $block.Data

            $setVariablesAndRunBlock = {
                param ($private:______parameters)

                foreach ($private:______current in $private:______parameters.Context.GetEnumerator()) {
                    $ExecutionContext.SessionState.PSVariable.Set($private:______current.Key, $private:______current.Value)
                }

                $private:______current = $null

                . $private:______parameters.ScriptBlock
            }

            $parameters = @{
                Context     = $context
                ScriptBlock = $ScriptBlock
            }

            $SessionStateInternal = $script:ScriptBlockSessionStateInternalProperty.GetValue($ScriptBlock, $null)
            $script:ScriptBlockSessionStateInternalProperty.SetValue($setVariablesAndRunBlock, $SessionStateInternal, $null)

            & $setVariablesAndRunBlock $parameters
        }
        else {
            & $ScriptBlock
        }

        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope DiscoveryCore "Finished discovering in body of block $Name"
        }
    }
    finally {
        $state.CurrentBlock = $previousBlock
        $null = $state.Stack.Pop()
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Runtime "Left block $Name"
        }
    }
}

function Invoke-Block ($previousBlock) {
    Switch-Timer -Scope Framework
    $overheadStartTime = $state.FrameworkStopWatch.Elapsed
    $blockStartTime = $state.UserCodeStopWatch.Elapsed

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Runtime "Entering path $($path -join '.')"
    }

    foreach ($item in $previousBlock.Order) {
        if ('Test' -eq $item.ItemType) {
            Invoke-TestItem -Test $item
        }
        else {
            $block = $item
            $state.CurrentBlock = $block
            try {
                if (-not $block.ShouldRun) {
                    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                        Write-PesterDebugMessage -Scope Runtime "Block '$($block.Name)' is excluded from run, returning"
                    }
                    continue
                }

                $block.ExecutedAt = [DateTime]::Now
                $block.Executed = $true

                # update ExpandedPath to included expanded parent name in case this fails in setup
                if (-not $block.Parent.IsRoot) { $block.ExpandedPath = "$($block.Parent.ExpandedPath).$($block.Name)" }

                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Runtime "Executing body of block '$($block.Name)'"
                }

                # no callbacks are provided because we are not transitioning between any states
                $frameworkSetupResult = Invoke-ScriptBlock `
                    -OuterSetup @(
                    if ($block.First) { $state.Plugin.OneTimeBlockSetupStart }
                ) `
                    -Setup @( $state.Plugin.EachBlockSetupStart ) `
                    -Context @{
                    Context = @{
                        # context that is visible to plugins
                        Block         = $block
                        Test          = $null
                        Configuration = $state.PluginConfiguration
                    }
                }

                if ($frameworkSetupResult.Success) {
                    # this craziness makes one extra scope that is bound to the user session state
                    # and inside of it the Invoke-Block is called recursively. Ultimately this invokes all blocks
                    # in their own scope like this:
                    # & { # block 1
                    #     . block 1 setup
                    #     & { # block 2
                    #         . block 2 setup
                    #         & { # block 3
                    #             . block 3 setup
                    #             & { # test one
                    #                 . test 1 setup
                    #                 . test1
                    #             }
                    #         }
                    #     }
                    # }

                    $sb = {
                        param($______pester_invoke_block_parameters)
                        & $______pester_invoke_block_parameters.Invoke_Block -previousBlock $______pester_invoke_block_parameters.Block
                    }

                    $context = @{
                        ______pester_invoke_block_parameters = @{
                            Invoke_Block = ${function:Invoke-Block}
                            Block        = $block
                        }
                        ____Pester                           = $State
                    }

                    if ($null -ne $block.Data) {
                        Add-DataToContext -Destination $context -Data $block.Data
                    }

                    $sessionStateInternal = $script:ScriptBlockSessionStateInternalProperty.GetValue($block.ScriptBlock, $null)
                    $script:ScriptBlockSessionStateInternalProperty.SetValue($sb, $SessionStateInternal)

                    $result = Invoke-ScriptBlock `
                        -ScriptBlock $sb `
                        -OuterSetup @(
                        $(if (-not (Is-Discovery) -and (-not $Block.Skip)) {
                                @($previousBlock.EachBlockSetup) + @($block.OneTimeTestSetup)
                            })
                        $(if (-not $Block.IsRoot) {
                                # expand block name by evaluating the <> templates, only match templates that have at least 1 character and are not escaped by `<abc`>
                                # avoid using variables so we don't run into conflicts
                                $sb = {

                                    $____Pester.CurrentBlock.ExpandedName = if ($____Pester.CurrentBlock.Name -like "*<*") { & ([ScriptBlock]::Create(('"' + ($____Pester.CurrentBlock.Name -replace '\$', '`$' -replace '"', '`"' -replace '(?<!`)<([^>^`]+)>', '$$($$$1)') + '"'))) } else { $____Pester.CurrentBlock.Name }

                                    $____Pester.CurrentBlock.ExpandedPath = if ($____Pester.CurrentBlock.Parent.IsRoot) {
                                        # to avoid including Root name in the path
                                        $____Pester.CurrentBlock.ExpandedName
                                    }
                                    else {
                                        "$($____Pester.CurrentBlock.Parent.ExpandedPath).$($____Pester.CurrentBlock.ExpandedName)"
                                    }
                                }

                                $SessionStateInternal = $script:ScriptBlockSessionStateInternalProperty.GetValue($State.CurrentBlock.ScriptBlock, $null)
                                $script:ScriptBlockSessionStateInternalProperty.SetValue($sb, $SessionStateInternal)

                                $sb
                            })
                    ) `
                        -OuterTeardown $( if (-not (Is-Discovery) -and (-not $Block.Skip)) {
                            @($block.OneTimeTestTeardown) + @($previousBlock.EachBlockTeardown)
                        } ) `
                        -Context $context `
                        -MoveBetweenScopes `
                        -Configuration $state.Configuration

                    $block.OwnPassed = $result.Success
                    $block.StandardOutput = $result.StandardOutput

                    $block.ErrorRecord.AddRange($result.ErrorRecord)
                    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                        Write-PesterDebugMessage -Scope Runtime "Finished executing body of block $Name"
                    }
                }

                $frameworkEachBlockTeardowns = @($state.Plugin.EachBlockTeardownEnd )
                $frameworkOneTimeBlockTeardowns = @( if ($block.Last) { $state.Plugin.OneTimeBlockTeardownEnd } )
                # reverse the teardowns so they run in opposite order to setups
                [Array]::Reverse($frameworkEachBlockTeardowns)
                [Array]::Reverse($frameworkOneTimeBlockTeardowns)


                # setting those values here so they are available for the teardown
                # BUT they are then set again at the end of the block to make them accurate
                # so the value on the screen vs the value in the object is slightly different
                # with the value in the result being the correct one
                $block.UserDuration = $state.UserCodeStopWatch.Elapsed - $blockStartTime
                $block.FrameworkDuration = $state.FrameworkStopWatch.Elapsed - $overheadStartTime
                $frameworkTeardownResult = Invoke-ScriptBlock `
                    -Teardown $frameworkEachBlockTeardowns `
                    -OuterTeardown $frameworkOneTimeBlockTeardowns `
                    -Context @{
                    Context = @{
                        # context that is visible to plugins
                        Block         = $block
                        Test          = $null
                        Configuration = $state.PluginConfiguration
                    }
                }

                if (-not $frameworkSetupResult.Success -or -not $frameworkTeardownResult.Success) {
                    Assert-Success -InvocationResult @($frameworkSetupResult, $frameworkTeardownResult) -Message "Framework failed"
                }
            }
            finally {
                $state.CurrentBlock = $previousBlock
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Runtime "Left block $Name"
                }
                $block.UserDuration = $state.UserCodeStopWatch.Elapsed - $blockStartTime
                $block.FrameworkDuration = $state.FrameworkStopWatch.Elapsed - $overheadStartTime
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Timing "Block duration $($block.UserDuration.TotalMilliseconds)ms"
                    Write-PesterDebugMessage -Scope Timing "Block framework duration $($block.FrameworkDuration.TotalMilliseconds)ms"
                    Write-PesterDebugMessage -Scope Runtime "Leaving path $($path -join '.')"
                }
            }
        }
    }
}

# endpoint for adding a test
function New-Test {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String] $Name,
        [Parameter(Mandatory = $true, Position = 1)]
        [ScriptBlock] $ScriptBlock,
        [int] $StartLine = $MyInvocation.ScriptLineNumber,
        [String[]] $Tag = @(),
        $Data,
        [String] $GroupId,
        [Switch] $Focus,
        [Switch] $Skip
    )

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope DiscoveryCore "Entering test $Name"
    }

    if ($state.CurrentBlock.IsRoot) {
        throw "Test cannot be directly in the root."
    }

    # avoid managing state by not pushing to the stack only to pop out in finally
    # simply concatenate the arrays
    $path = @(<# Get full name #> $history = $state.Stack.ToArray(); [Array]::Reverse($history); $history + $name)

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Runtime "Entering path $($path -join '.')"
    }

    $test = [Pester.Test]::Create()
    $test.GroupId = $GroupId
    $test.ScriptBlock = $ScriptBlock
    $test.Name = $Name
    # using the non-expanded name as default to fallback to it if we don't
    # reach the point where we expand it, for example because of setup failure
    $test.ExpandedName = $Name
    $test.Path = $path
    # using the non-expanded path as default to fallback to it if we don't
    # reach the point where we expand it, for example because of setup failure
    $test.ExpandedPath = $path -join '.'
    $test.StartLine = $StartLine
    $test.Tag = $Tag
    $test.Focus = $Focus
    $test.Skip = $Skip
    $test.Data = $Data
    $test.FrameworkData.Runtime.Phase = 'Discovery'

    # add test to current block lists
    $state.CurrentBlock.Tests.Add($Test)
    $state.CurrentBlock.Order.Add($Test)

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope DiscoveryCore "Added test '$Name'"
    }
}

function Invoke-TestItem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Test
    )
    # keep this at the top so we report as much time
    # of the actual test run as possible
    $overheadStartTime = $state.FrameworkStopWatch.Elapsed
    $testStartTime = $state.UserCodeStopWatch.Elapsed
    Switch-Timer -Scope Framework

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Runtime "Entering test $($Test.Name)"
    }

    try {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Runtime "Entering path $($Test.Path -join '.')"
        }

        $Test.FrameworkData.Runtime.Phase = 'Execution'
        Set-CurrentTest -Test $Test

        if (-not $Test.ShouldRun) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Runtime "Test is excluded from run, returning"
            }
            return
        }

        $Test.ExecutedAt = [DateTime]::Now
        $Test.Executed = $true

        $block = $Test.Block
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Runtime "Running test '$($Test.Name)'."
        }

        # no callbacks are provided because we are not transitioning between any states
        $frameworkSetupResult = Invoke-ScriptBlock `
            -OuterSetup @(
            if ($Test.First) { $state.Plugin.OneTimeTestSetupStart }
        ) `
            -Setup @( $state.Plugin.EachTestSetupStart ) `
            -Context @{
            Context = @{
                # context visible to Plugins
                Block         = $block
                Test          = $Test
                Configuration = $state.PluginConfiguration
            }
        }

        # update ExpandedPath to included expanded parent name in case this fails in setup
        $Test.ExpandedPath = "$($block.ExpandedPath).$($Test.Name)"

        if ($Test.Skip) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                $path = $Test.Path -join '.'
                Write-PesterDebugMessage -Scope Skip "($path) Test is skipped."
            }

            # setting the test as passed here, this is by choice
            # skipped test are ultimately passed tests that were not executed
            # I expect that if someone works with the raw result object and
            # filters on .Passed -eq $false they should get the count of failed tests
            # not failed + skipped. It might be wise to revert those booleans to "enum"
            # because they are exclusive, but keeping the info in the object stupid
            # and aggregating it as needed was also a design choice
            $Test.Passed = $true
            $Test.Skipped = $true
            $Test.FrameworkData.Runtime.ExecutionStep = 'Finished'
        }
        else {

            if ($frameworkSetupResult.Success) {
                $context = @{
                    ____Pester = $State
                }

                if ($null -ne $test.Data) {
                    Add-DataToContext -Destination $context -Data $test.Data
                }

                # recurse up Recurse-Up $Block { param ($b) $b.EachTestSetup }
                $i = $Block
                $eachTestSetups = while ($null -ne $i) {
                    $i.EachTestSetup
                    $i = $i.Parent
                }

                # recurse up Recurse-Up $Block { param ($b) $b.EachTestTeardown }
                $i = $Block
                $eachTestTeardowns = while ($null -ne $i) {
                    $i.EachTestTeardown
                    $i = $i.Parent
                }

                $result = Invoke-ScriptBlock `
                    -Setup @(
                    if ($null -ne $eachTestSetups -and 0 -lt @($eachTestSetups).Count) {
                        # we collect the child first but want the parent to run first
                        [Array]::Reverse($eachTestSetups)
                        @( { $Test.FrameworkData.Runtime.ExecutionStep = 'EachTestSetup' }) + @($eachTestSetups)
                    }

                    {
                        # setting the execution info here so I don't have to invoke change the
                        # contract of Invoke-ScriptBlock to accept multiple -ScriptBlock, because
                        # that is not needed, and would complicate figuring out in which session
                        # state we should run.
                        # this should run every time.
                        $Test.FrameworkData.Runtime.ExecutionStep = 'Test'
                    }
                    $(
                        # expand block name by evaluating the <> templates, only match templates that have at least 1 character and are not escaped by `<abc`>
                        # avoid using any variables to avoid running into conflict with user variables
                        # $ExecutionContext.SessionState.InvokeCommand.ExpandString() has some weird bug in PowerShell 4 and 3, that makes hashtable resolve to null
                        # instead I create a expandable string in a scriptblock and evaluate
                        $sb = {

                            $____Pester.CurrentTest.ExpandedName = if ($____Pester.CurrentTest.Name -like "*<*") {
                                & ([ScriptBlock]::Create(('"' + ($____Pester.CurrentTest.Name -replace '\$', '`$' -replace '"', '`"' -replace '(?<!`)<([^>^`]+)>', '$$($$$1)') + '"')))
                            }
                            else {
                                $____Pester.CurrentTest.Name
                            }

                            $____Pester.CurrentTest.ExpandedPath = "$($____Pester.CurrentTest.Block.ExpandedPath -join '.').$($____Pester.CurrentTest.ExpandedName)"
                        }

                        $SessionStateInternal = $script:ScriptBlockSessionStateInternalProperty.GetValue($State.CurrentTest.ScriptBlock, $null)
                        $script:ScriptBlockSessionStateInternalProperty.SetValue($sb, $SessionStateInternal)
                        $sb
                    )
                ) `
                    -ScriptBlock $Test.ScriptBlock `
                    -Teardown @(
                    if ($null -ne $eachTestTeardowns -and 0 -lt @($eachTestTeardowns).Count) {
                        @( { $Test.FrameworkData.Runtime.ExecutionStep = 'EachTestTeardown' }) + @($eachTestTeardowns)
                    } ) `
                    -Context $context `
                    -ReduceContextToInnerScope `
                    -MoveBetweenScopes `
                    -NoNewScope `
                    -Configuration $state.Configuration

                $Test.FrameworkData.Runtime.ExecutionStep = 'Finished'

                if (@('PesterTestSkipped', 'PesterTestInconclusive') -contains $Result.ErrorRecord.FullyQualifiedErrorId) {
                    #Same logic as when setting a test block to skip
                    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                        $path = $Test.Path -join '.'
                        Write-PesterDebugMessage -Scope Skip "($path) Test is skipped."
                    }
                    $Test.Passed = $true
                    if ('PesterTestInconclusive' -eq $Result.ErrorRecord.FullyQualifiedErrorId) {
                        $Test.Inconclusive = $true
                    }
                    else {
                        $Test.Skipped = $true
                    }
                }
                else {
                    $Test.Passed = $result.Success
                }

                $Test.StandardOutput = $result.StandardOutput
                $Test.ErrorRecord.AddRange($result.ErrorRecord)
            }
        }


        # setting those values here so they are available for the teardown
        # BUT they are then set again at the end of the block to make them accurate
        # so the value on the screen vs the value in the object is slightly different
        # with the value in the result being the correct one
        $Test.UserDuration = $state.UserCodeStopWatch.Elapsed - $testStartTime
        $Test.FrameworkDuration = $state.FrameworkStopWatch.Elapsed - $overheadStartTime

        $frameworkEachTestTeardowns = @( $state.Plugin.EachTestTeardownEnd )
        $frameworkOneTimeTestTeardowns = @(if ($Test.Last) { $state.Plugin.OneTimeTestTeardownEnd })
        [array]::Reverse($frameworkEachTestTeardowns)
        [array]::Reverse($frameworkOneTimeTestTeardowns)

        $frameworkTeardownResult = Invoke-ScriptBlock `
            -Teardown $frameworkEachTestTeardowns `
            -OuterTeardown $frameworkOneTimeTestTeardowns `
            -Context @{
            Context = @{
                # context visible to Plugins
                Test          = $Test
                Block         = $block
                Configuration = $state.PluginConfiguration
            }
        }

        if (-not $frameworkTeardownResult.Success -or -not $frameworkTeardownResult.Success) {
            throw $frameworkTeardownResult.ErrorRecord[-1]
        }

    }
    finally {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Runtime "Leaving path $($Test.Path -join '.')"
        }
        $state.CurrentTest = $null
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Runtime "Left test $($Test.Name)"
        }

        # keep this at the end so we report even the test teardown in the framework overhead for the test
        $Test.UserDuration = $state.UserCodeStopWatch.Elapsed - $testStartTime
        $Test.FrameworkDuration = $state.FrameworkStopWatch.Elapsed - $overheadStartTime
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Timing -Message "Test duration $($Test.UserDuration.TotalMilliseconds)ms"
            Write-PesterDebugMessage -Scope Timing -Message "Framework duration $($Test.FrameworkDuration.TotalMilliseconds)ms"
        }
    }
}

# endpoint for adding a setup for each test in the block
function New-EachTestSetup {
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )

    if (Is-Discovery) {
        $state.CurrentBlock.EachTestSetup = $ScriptBlock
    }
}

# endpoint for adding a teardown for each test in the block
function New-EachTestTeardown {
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )

    if (Is-Discovery) {
        $state.CurrentBlock.EachTestTeardown = $ScriptBlock
    }
}

# endpoint for adding a setup for all tests in the block
function New-OneTimeTestSetup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )

    if (Is-Discovery) {
        $state.CurrentBlock.OneTimeTestSetup = $ScriptBlock
    }
}

# endpoint for adding a teardown for all tests in the block
function New-OneTimeTestTeardown {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )
    if (Is-Discovery) {
        $state.CurrentBlock.OneTimeTestTeardown = $ScriptBlock
    }
}

# endpoint for adding a setup for each block in the current block
function New-EachBlockSetup {
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )
    if (Is-Discovery) {
        $state.CurrentBlock.EachBlockSetup = $ScriptBlock
    }
}

# endpoint for adding a teardown for each block in the current block
function New-EachBlockTeardown {
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )
    if (Is-Discovery) {
        $state.CurrentBlock.EachBlockTeardown = $ScriptBlock
    }
}

# endpoint for adding a setup for all blocks in the current block
function New-OneTimeBlockSetup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )
    if (Is-Discovery) {
        $state.CurrentBlock.OneTimeBlockSetup = $ScriptBlock
    }
}

# endpoint for adding a teardown for all clocks in the current block
function New-OneTimeBlockTeardown {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )
    if (Is-Discovery) {
        $state.CurrentBlock.OneTimeBlockTeardown = $ScriptBlock
    }
}

function Get-CurrentBlock {
    [CmdletBinding()]
    param()

    $state.CurrentBlock
}

function Get-CurrentTest {
    [CmdletBinding()]
    param()

    $state.CurrentTest
}

function Set-CurrentBlock {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Block
    )

    $state.CurrentBlock = $Block
}


function Set-CurrentTest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Test
    )

    $state.CurrentTest = $Test
}


function Is-Discovery {
    $state.Discovery
}

function Discover-Test {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSObject[]] $BlockContainer,
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState,
        $Filter
    )
    $totalDiscoveryDuration = [Diagnostics.Stopwatch]::StartNew()

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Discovery -Message "Starting test discovery in $(@($BlockContainer).Length) test containers."
    }

    $steps = $state.Plugin.DiscoveryStart
    if ($null -ne $steps -and 0 -lt @($steps).Count) {
        Invoke-PluginStep -Plugins $state.Plugin -Step DiscoveryStart -Context @{
            BlockContainers = $BlockContainer
            Configuration   = $state.PluginConfiguration
        } -ThrowOnFailure
    }

    $state.Discovery = $true
    $found = foreach ($container in $BlockContainer) {
        $perContainerDiscoveryDuration = [Diagnostics.Stopwatch]::StartNew()

        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Discovery "Discovering tests in $($container.Item)"
        }

        # this is a block object that we add so we can capture
        # OneTime* and Each* setups, and capture multiple blocks in a
        # container
        $root = [Pester.Block]::Create()
        $root.ExpandedName = $root.Name = "Root"

        $root.IsRoot = $true
        $root.ExpandedPath = $root.Path = "Path"

        $root.First = $true
        $root.Last = $true

        # set the data from the container to get them
        # set correctly as if we provided -Data to New-Block
        $root.Data = $container.Data

        Reset-PerContainerState -RootBlock $root

        $steps = $state.Plugin.ContainerDiscoveryStart
        if ($null -ne $steps -and 0 -lt @($steps).Count) {
            Invoke-PluginStep -Plugins $state.Plugin -Step ContainerDiscoveryStart -Context @{
                BlockContainer = $container
                Configuration  = $state.PluginConfiguration
            } -ThrowOnFailure
        }

        try {
            $null = Invoke-BlockContainer -BlockContainer $container -SessionState $SessionState
        }
        catch {
            $root.Passed = $false
            $root.Result = "Failed"
            $root.ErrorRecord.Add($_)
        }

        [PSCustomObject] @{
            Container = $container
            Block     = $root
        }

        $steps = $state.Plugin.ContainerDiscoveryEnd
        if ($null -ne $steps -and 0 -lt @($steps).Count) {
            Invoke-PluginStep -Plugins $state.Plugin -Step ContainerDiscoveryEnd -Context @{
                BlockContainer = $container
                Block          = $root
                Duration       = $perContainerDiscoveryDuration.Elapsed
                Configuration  = $state.PluginConfiguration
            } -ThrowOnFailure
        }

        $root.DiscoveryDuration = $perContainerDiscoveryDuration.Elapsed
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Discovery -LazyMessage { "Found $(@(View-Flat -Block $root).Count) tests in $([int]$root.DiscoveryDuration.TotalMilliseconds) ms" }
            Write-PesterDebugMessage -Scope DiscoveryCore "Discovery done in this container."
        }
    }

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Discovery "Processing discovery result objects, to set root, parents, filters etc."
    }

    # focusing is removed from the public api
    # # if any tests / block in the suite have -Focus parameter then all filters are disregarded
    # # and only those tests / blocks should run
    # $focusedTests = [System.Collections.Generic.List[Object]]@()
    # foreach ($f in $found) {
    #     Fold-Container -Container $f.Block `
    #         -OnTest {
    #             # add all focused tests
    #             param($t)
    #             if ($t.Focus) {
    #                 $focusedTests.Add("$(if($null -ne $t.ScriptBlock.File) { $t.ScriptBlock.File } else { $t.ScriptBlock.Id }):$($t.ScriptBlock.StartPosition.StartLine)")
    #             }
    #         } `
    #         -OnBlock {
    #             param($b) if ($b.Focus) {
    #                 # add all tests in the current block, no matter if they are focused or not
    #                 Fold-Block -Block $b -OnTest {
    #                     param ($t)
    #                     $focusedTests.Add("$(if($null -ne $t.ScriptBlock.File) { $t.ScriptBlock.File } else { $t.ScriptBlock.Id }):$($t.ScriptBlock.StartPosition.StartLine)")
    #                 }
    #             }
    #         }
    # }

    # if ($focusedTests.Count -gt 0) {
    #     if ($PesterPreference.Debug.WriteDebugMessages.Value) {
    #         Write-PesterDebugMessage -Scope Discovery  -LazyMessage { "There are some ($($focusedTests.Count)) focused tests '$($(foreach ($p in $focusedTests) { $p -join "." }) -join ",")' running just them." }
    #     }
    #     $Filter =  New-FilterObject -Line $focusedTests
    # }

    foreach ($f in $found) {
        # this takes non-trivial time, measure how long it takes and add it to the discovery
        # so we get more accurate total time
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        PostProcess-DiscoveredBlock -Block $f.Block -Filter $Filter -BlockContainer $f.Container -RootBlock $f.Block
        $overhead = $sw.Elapsed
        $f.Block.DiscoveryDuration += $overhead
        # Write-Host "disc $($f.Block.DiscoveryDuration.totalmilliseconds) $($overhead.totalmilliseconds) ms" #TODO
        $f.Block
    }

    $steps = $state.Plugin.DiscoveryEnd
    if ($null -ne $steps -and 0 -lt @($steps).Count) {
        Invoke-PluginStep -Plugins $state.Plugin -Step DiscoveryEnd -Context @{
            BlockContainers = $found.Block
            AnyFocusedTests = $focusedTests.Count -gt 0
            FocusedTests    = $focusedTests
            Duration        = $totalDiscoveryDuration.Elapsed
            Configuration   = $state.PluginConfiguration
            Filter          = $Filter
        } -ThrowOnFailure
    }

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Discovery "Test discovery finished."
    }
}

function Run-Test {
    param (
        [Parameter(Mandatory = $true)]
        [PSObject[]] $Block,
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState
    )

    $state.Discovery = $false
    $steps = $state.Plugin.RunStart
    if ($null -ne $steps -and 0 -lt @($steps).Count) {
        Invoke-PluginStep -Plugins $state.Plugin -Step RunStart -Context @{
            Blocks                   = $Block
            Configuration            = $state.PluginConfiguration
            Data                     = $state.PluginData
            WriteDebugMessages       = $PesterPreference.Debug.WriteDebugMessages.Value
            Write_PesterDebugMessage = if ($PesterPreference.Debug.WriteDebugMessages.Value) { $script:SafeCommands['Write-PesterDebugMessage'] }
        } -ThrowOnFailure
    }
    foreach ($rootBlock in $Block) {
        $blockStartTime = $state.UserCodeStopWatch.Elapsed
        $overheadStartTime = $state.FrameworkStopWatch.Elapsed
        Switch-Timer -Scope Framework

        if (-not $rootBlock.ShouldRun) {
            ConvertTo-ExecutedBlockContainer -Block $rootBlock
            continue
        }
        # this resets the timers so keep that before measuring the time
        Reset-PerContainerState -RootBlock $rootBlock

        $rootBlock.Executed = $true
        $rootBlock.ExecutedAt = [DateTime]::now

        $steps = $state.Plugin.ContainerRunStart
        if ($null -ne $steps -and 0 -lt @($steps).Count) {
            Invoke-PluginStep -Plugins $state.Plugin -Step ContainerRunStart -Context @{
                Block         = $rootBlock
                Configuration = $state.PluginConfiguration
            } -ThrowOnFailure
        }

        try {
            # if ($null -ne $rootBlock.OneTimeBlockSetup) {
            #    throw "One time block setup is not supported in root (directly in the block container)."
            #}

            # if ($null -ne $rootBlock.EachBlockSetup) {
            #     throw "Each block setup is not supported in root (directly in the block container)."
            # }

            if ($null -ne $rootBlock.EachTestSetup) {
                throw "Each test setup is not supported in root (directly in the block container)."
            }

            if (
                $null -ne $rootBlock.EachTestTeardown
                #-or $null -ne $rootBlock.OneTimeBlockTeardown `
                #-or $null -ne $rootBlock.EachBlockTeardown `
            ) {
                throw "Each test Teardown is not supported in root (directly in the block container)."
            }

            # add OneTimeTestSetup to set variables, by having $setVariables script that will invoke in the user scope
            # and $setVariablesWithContext that carries the data as is closure, this way we avoid having to provide parameters to
            # before all script, but it might be better to make this a plugin, because there we can pass data.
            $setVariables = {
                param($private:____parameters)

                if ($null -eq $____parameters.Data) {
                    return
                }

                foreach ($private:____d in $____parameters.Data.GetEnumerator()) {
                    & $____parameters.Set_Variable -Name $private:____d.Key -Value $private:____d.Value
                }
            }

            $SessionStateInternal = $script:SessionStateInternalProperty.GetValue($SessionState, $null)
            $script:ScriptBlockSessionStateInternalProperty.SetValue($setVariables, $SessionStateInternal, $null)

            $setVariablesAndThenRunOneTimeSetupIfAny = & {
                $action = $setVariables
                $setup = $rootBlock.OneTimeTestSetup
                $parameters = @{
                    Data         = $rootBlock.BlockContainer.Data
                    Set_Variable = $SafeCommands["Set-Variable"]
                }

                {
                    . $action $parameters
                    if ($null -ne $setup) {
                        . $setup
                    }
                }.GetNewClosure()
            }

            $rootBlock.OneTimeTestSetup = $setVariablesAndThenRunOneTimeSetupIfAny

            $rootBlock.ScriptBlock = {}
            $SessionStateInternal = $script:SessionStateInternalProperty.GetValue($SessionState, $null)
            $script:ScriptBlockSessionStateInternalProperty.SetValue($rootBlock.ScriptBlock, $SessionStateInternal, $null)

            # we add one more artificial block so the root can run
            # all of it's setups and teardowns
            $Pester___parent = [Pester.Block]::Create()
            $Pester___parent.Name = "ParentBlock"
            $Pester___parent.Path = "Path"

            $Pester___parent.First = $false
            $Pester___parent.Last = $false

            $Pester___parent.Order.Add($rootBlock)

            $wrapper = {
                $null = Invoke-Block -previousBlock $Pester___parent
            }

            Invoke-InNewScriptScope -ScriptBlock $wrapper -SessionState $SessionState
        }
        catch {
            $rootBlock.ErrorRecord.Add($_)
        }

        PostProcess-ExecutedBlock -Block $rootBlock
        $result = ConvertTo-ExecutedBlockContainer -Block $rootBlock
        $result.FrameworkDuration = $state.FrameworkStopWatch.Elapsed - $overheadStartTime
        $result.UserDuration = $state.UserCodeStopWatch.Elapsed - $blockStartTime

        $steps = $state.Plugin.ContainerRunEnd
        if ($null -ne $steps -and 0 -lt @($steps).Count) {
            Invoke-PluginStep -Plugins $state.Plugin -Step ContainerRunEnd -Context @{
                Result        = $result
                Block         = $rootBlock
                Configuration = $state.PluginConfiguration
            } -ThrowOnFailure
        }

        # set this again so the plugins have some data but that we also include the plugin invocation to the
        # overall time to keep the actual timing correct
        $result.FrameworkDuration = $state.FrameworkStopWatch.Elapsed - $overheadStartTime
        $result.UserDuration = $state.UserCodeStopWatch.Elapsed - $blockStartTime
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Timing "Container duration $($result.UserDuration.TotalMilliseconds)ms"
            Write-PesterDebugMessage -Scope Timing "Container framework duration $($result.FrameworkDuration.TotalMilliseconds)ms"
        }

        $result
    }

    $steps = $state.Plugin.RunEnd
    if ($null -ne $steps -and 0 -lt @($steps).Count) {
        Invoke-PluginStep -Plugins $state.Plugin -Step RunEnd -Context @{
            Blocks                   = $Block
            Configuration            = $state.PluginConfiguration
            Data                     = $state.PluginData
            WriteDebugMessages       = $PesterPreference.Debug.WriteDebugMessages.Value
            Write_PesterDebugMessage = if ($PesterPreference.Debug.WriteDebugMessages.Value) { $script:SafeCommands['Write-PesterDebugMessage'] }
        } -ThrowOnFailure
    }
}

function Invoke-PluginStep {
    # [CmdletBinding()]
    param (
        [PSObject[]] $Plugins,
        [Parameter(Mandatory)]
        [ValidateSet('Start', 'DiscoveryStart', 'ContainerDiscoveryStart', 'BlockDiscoveryStart', 'TestDiscoveryStart', 'TestDiscoveryEnd', 'BlockDiscoveryEnd', 'ContainerDiscoveryEnd', 'DiscoveryEnd', 'RunStart', 'ContainerRunStart', 'OneTimeBlockSetupStart', 'EachBlockSetupStart', 'OneTimeTestSetupStart', 'EachTestSetupStart', 'EachTestTeardownEnd', 'OneTimeTestTeardownEnd', 'EachBlockTeardownEnd', 'OneTimeBlockTeardownEnd', 'ContainerRunEnd', 'RunEnd', 'End')]
        [String] $Step,
        $Context = @{ },
        [Switch] $ThrowOnFailure
    )

    # there are actually two ways to invoke plugin steps, this unified cmdlet that allows us to run the steps
    # in isolation, and then another where we are using Invoke-ScriptBlock directly when we need the plugin to run
    # for example as a teardown step of a test.

    # switch-timer framework
    $state.UserCodeStopWatch.Stop()
    $state.FrameworkStopWatch.Start()

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        $sw = [Diagnostics.Stopwatch]::StartNew()
    }

    $pluginsWithGivenStep = @(foreach ($p in $Plugins) { if ($null -ne $p.$Step) { $p } })

    if ($null -eq $pluginsWithGivenStep -or 0 -eq @($pluginsWithGivenStep).Count) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope PluginCore "No plugins with step $Step were provided"
        }
        return
    }

    # this is end step, we should run all steps no matter if some failed, and we should run them in opposite direction
    # only do this if there is more than 1, to avoid the "expensive" -like check and reverse
    $isEndStep = 1 -lt $pluginsWithGivenStep.Count -and $Step -like "*End"
    if (-not $isEndStep) {
        [Array]::Reverse($pluginsWithGivenStep)
    }

    $err = [Collections.Generic.List[Management.Automation.ErrorRecord]]@()
    $failed = $false
    # the plugins expect -Context and then the actual context in it
    # this was a choice at the start of the project to make it easy to see
    # what is available, not sure if a good choice
    $ctx = @{
        Context = $Context
    }
    $standardOutput =
    foreach ($p in $pluginsWithGivenStep) {
        if ($failed -and -not $isEndStep) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Plugin "Skipping $($p.Name) step $Step because some previous plugin failed"
            }
            continue
        }

        try {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                $stepSw = [Diagnostics.Stopwatch]::StartNew()
                $hasContext = 0 -lt $Context.Count
                $c = if ($hasContext) { $Context | & $script:SafeCommands['Out-String'] }
                Write-PesterDebugMessage -Scope Plugin "Running $($p.Name) step $Step $(if ($hasContext) { "with context: $c" } else { "without any context"})"
            }

            do {
                & $p.$Step @ctx
            } while ($false)

            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Plugin "Success $($p.Name) step $Step in $($stepSw.ElapsedMilliseconds) ms"
            }
        }
        catch {
            $failed = $true
            $err.Add($_)
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Plugin "Failed $($p.Name) step $Step in $($stepSw.ElapsedMilliseconds) ms" -ErrorRecord $_
            }
        }
    }

    if ($ThrowOnFailure) {
        if ($failed) {
            $r = [Pester.InvocationResult]::Create((-not $failed), $err, $standardOutput)
            Assert-Success $r -Message "Invoking step $step failed"
        }
        else {
            # do nothing, especially don't create or return the result object
        }
    }
    else {
        $r = [Pester.InvocationResult]::Create((-not $failed), $err, $standardOutput)
        return $r
    }
}

function Assert-Success {
    # [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject[]] $InvocationResult,
        [String] $Message = "Invocation failed"
    )

    $rc = 0
    $anyFailed = $false
    $err = ""
    foreach ($r in $InvocationResult) {
        $rc++
        $ec = 0
        if ($null -ne $r.ErrorRecord -and $r.ErrorRecord.Length -gt 0) {
            $anyFailed = $true
            foreach ($e in $r.ErrorRecord) {
                $err += "$([Environment]::NewLine)Result $rc - Error $((++$ec)):"
                $err += & $SafeCommands["Out-String"] -InputObject $e
                $err += & $SafeCommands["Out-String"] -InputObject $e.ScriptStackTrace
            }
        }
    }

    if ($anyFailed) {
        $Message = $Message + ":$err"
        throw $Message
    }
}

function Invoke-ScriptBlock {
    param(
        [ScriptBlock] $ScriptBlock,
        [ScriptBlock[]] $OuterSetup,
        [ScriptBlock[]] $Setup,
        [ScriptBlock[]] $Teardown,
        [ScriptBlock[]] $OuterTeardown,
        $Context = @{ },
        # define data to be shared in only in the inner scope where e.g eachTestSetup + test run but not
        # in the scope where OneTimeTestSetup runs, on the other hand, plugins want context
        # in all scopes
        [Switch] $ReduceContextToInnerScope,
        # # setup, body and teardown will all run (be-dotsourced into)
        # # the same scope
        # [Switch] $SameScope,
        # will dot-source the wrapper scriptblock instead of invoking it
        # so in combination with the SameScope switch we are effectively
        # running the code in the current scope
        [Switch] $NoNewScope,
        [Switch] $MoveBetweenScopes,
        [ScriptBlock] $OnUserScopeTransition = $null,
        [ScriptBlock] $OnFrameworkScopeTransition = $null,
        $Configuration
    )

    # filter nulls, inlined to avoid overhead of combineNonNull and selectNonNull
    $OuterSetup = if ($null -ne $OuterSetup -and 0 -lt $OuterSetup.Count) {
        foreach ($i in $OuterSetup) {
            if ($null -ne $i) {
                $i
            }
        }
    }

    $Setup = if ($null -ne $Setup -and 0 -lt $Setup.Count) {
        foreach ($i in $Setup) {
            if ($null -ne $i) {
                $i
            }
        }
    }

    $Teardown = if ($null -ne $Teardown -and 0 -lt $Teardown.Count) {
        foreach ($i in $Teardown) {
            if ($null -ne $i) {
                $i
            }
        }
    }

    $OuterTeardown = if ($null -ne $OuterTeardown -and 0 -lt $OuterTeardown.Count) {
        foreach ($i in $OuterTeardown) {
            if ($null -ne $i) {
                $i
            }
        }
    }





    # this is what the code below does
    # . $OuterSetup
    # & {
    #     try {
    #       # import setup to scope
    #       . $Setup
    #       # executed the test code in the same scope
    #       . $ScriptBlock
    #     } finally {
    #       . $Teardown
    #     }
    # }
    # . $OuterTeardown


    $wrapperScriptBlock = {
        # THIS RUNS (MOST OF THE TIME) IN USER SCOPE, BE CAREFUL WHAT YOU PUBLISH AND CONSUME!
        param($______parameters)

        if (-not $______parameters.NoNewScope) {
            # a child runner that will not create a new scope will force itself into the current scope
            # and overwrite our params in the inner scope (denoted by & { below), keep a second reference to it
            # so we can use it for Teardowns and to forward errors that happened after test teardown
            $______parametersForward = $______parameters
        }



        try {
            if ($______parameters.ContextInOuterScope) {
                $______outerSplat = $______parameters.Context
                if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Setting context variables" }
                foreach ($______current in $______outerSplat.GetEnumerator()) {
                    if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Setting context variable '$($______current.Key)' with value '$($______current.Value)'" }
                    $ExecutionContext.SessionState.PSVariable.Set($______current.Key, $______current.Value)
                }

                if ($______outerSplat.ContainsKey("_")) {
                    $______outerSplat.Remove("_")
                }

                $______current = $null
            }
            else {
                $______outerSplat = @{ }
            }

            if ($null -ne $______parameters.OuterSetup -and $______parameters.OuterSetup.Length -gt 0) {
                if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Running outer setups" }
                foreach ($______current in $______parameters.OuterSetup) {
                    if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Running outer setup { $______current }" }
                    $______parameters.CurrentlyExecutingScriptBlock = $______current
                    . $______current @______outerSplat
                }
                $______current = $null
                $______parameters.OuterSetup = $null
                if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Done running outer setups" }
            }
            else {
                if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "There are no outer setups" }
            }

            & {
                try {

                    if (-not $______parameters.ContextInOuterScope) {
                        $______innerSplat = $______parameters.Context
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Setting context variables" }
                        foreach ($______current in $______innerSplat.GetEnumerator()) {
                            if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Setting context variable '$ ($______current.Key)' with value '$($______current.Value)'" }
                            $ExecutionContext.SessionState.PSVariable.Set($______current.Key, $______current.Value)
                        }

                        if ($______outerSplat.ContainsKey("_")) {
                            $______outerSplat.Remove("_")
                        }

                        $______current = $null
                    }
                    else {
                        $______innerSplat = $______outerSplat
                    }

                    if ($null -ne $______parameters.Setup -and $______parameters.Setup.Length -gt 0) {
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Running inner setups" }
                        foreach ($______current in $______parameters.Setup) {
                            if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Running inner setup { $______current }" }
                            $______parameters.CurrentlyExecutingScriptBlock = $______current
                            . $______current @______innerSplat
                        }
                        $______current = $null
                        $______parameters.Setup = $null
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Done running inner setups" }
                    }
                    else {
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "There are no inner setups" }
                    }

                    if ($null -ne $______parameters.ScriptBlock) {
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Running scriptblock { $($______parameters.ScriptBlock) }" }
                        $______parameters.CurrentlyExecutingScriptBlock = $______parameters.ScriptBlock
                        . $______parameters.ScriptBlock @______innerSplat

                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Done running scriptblock" }
                    }
                    else {
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "There is no scriptblock to run" }
                    }
                }
                catch {
                    $______parameters.ErrorRecord.Add($_)
                    if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Fail running setups or scriptblock" -ErrorRecord $_ }
                }
                finally {
                    if ($null -ne $______parameters.Teardown -and $______parameters.Teardown.Length -gt 0) {
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Running inner teardowns" }
                        if ($______parameters.MoveBetweenScopes) { & $______parameters.SwitchTimerUserCode }
                        foreach ($______current in $______parameters.Teardown) {
                            try {
                                if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Running inner teardown { $______current }" }
                                $______parameters.CurrentlyExecutingScriptBlock = $______current
                                . $______current @______innerSplat
                                if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Done running inner teardown" }
                            }
                            catch {
                                $______parameters.ErrorRecord.Add($_)
                                if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Fail running inner teardown" -ErrorRecord $_ }
                            }
                        }
                        $______current = $null

                        # nulling this variable is important when we run without new scope
                        # then $______parameters.Teardown remains set and EachBlockTeardown
                        # runs twice
                        $______parameters.Teardown = $null
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Done running inner teardowns" }
                    }
                    else {
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "There are no inner teardowns" }
                    }
                }
            }
        }
        finally {

            if ($null -ne $______parameters.OuterTeardown -and $______parameters.OuterTeardown.Length -gt 0) {
                if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Running outer teardowns" }
                if ($______parameters.MoveBetweenScopes) { & $______parameters.SwitchTimerUserCode }
                foreach ($______current in $______parameters.OuterTeardown) {
                    try {
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Running outer teardown { $______current }" }
                        $______parameters.CurrentlyExecutingScriptBlock = $______current
                        . $______current @______outerSplat
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Done running outer teardown" }
                    }
                    catch {
                        if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Fail running outer teardown" -ErrorRecord $_ }
                        $______parameters.ErrorRecord.Add($_)
                    }
                }
                $______parameters.OuterTeardown = $null
                $______current = $null
                if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "Done running outer teardowns" }
            }
            else {
                if ($______parameters.EnableWriteDebug) { &$______parameters.WriteDebug "There are no outer teardowns" }
            }

            if ($______parameters.NoNewScope -and $ExecutionContext.SessionState.PSVariable.GetValue('______parametersForward')) {
                $______parameters = $______parametersForward
            }
        }
    }

    if ($MoveBetweenScopes -and $null -ne $ScriptBlock) {
        $SessionStateInternal = $script:ScriptBlockSessionStateInternalProperty.GetValue($ScriptBlock, $null)
        # attach the original session state to the wrapper scriptblock
        # making it invoke in the same scope as $ScriptBlock
        $script:ScriptBlockSessionStateInternalProperty.SetValue($wrapperScriptBlock, $SessionStateInternal, $null)
    }

    $writeDebug = if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        {
            param($Message, [Management.Automation.ErrorRecord] $ErrorRecord)
            Write-PesterDebugMessage -Scope "RuntimeCore" $Message -ErrorRecord $ErrorRecord
        }
    }

    $switchTimerUserCode = if ($MoveBetweenScopes) {
        {
            $state.UserCodeStopWatch.Start()
            $state.FrameworkStopWatch.Stop()
        }
    }

    #$break = $true
    $err = $null
    try {
        $parameters = @{
            ScriptBlock                   = $ScriptBlock
            OuterSetup                    = $OuterSetup
            Setup                         = $Setup
            Teardown                      = $Teardown
            OuterTeardown                 = $OuterTeardown
            CurrentlyExecutingScriptBlock = $null
            ErrorRecord                   = [Collections.Generic.List[Management.Automation.ErrorRecord]]@()
            Context                       = $Context
            ContextInOuterScope           = -not $ReduceContextToInnerScope
            EnableWriteDebug              = $PesterPreference.Debug.WriteDebugMessages.Value
            WriteDebug                    = $writeDebug
            Configuration                 = $Configuration
            NoNewScope                    = $NoNewScope
            MoveBetweenScopes             = $MoveBetweenScopes
            SwitchTimerUserCode           = $switchTimerUserCode
        }

        # here we are moving into the user scope if the provided
        # scriptblock was bound to user scope, so we want to take some actions
        # typically switching between user and framework timer. There are still tiny pieces of
        # framework code running in the scriptblock but we can safely ignore those because they are
        # just logging, so the time difference is miniscule.
        # The code might also run just in framework scope, in that case the callback can remain empty,
        # eg when we are invoking framework setup.
        if ($MoveBetweenScopes) {
            # switch-timer to user scope inlined
            $state.UserCodeStopWatch.Start()
            $state.FrameworkStopWatch.Stop()

            if ($null -ne $OnUserScopeTransition) {
                & $OnUserScopeTransition
            }
        }
        do {
            $standardOutput = if ($NoNewScope) {
                . $wrapperScriptBlock $parameters
            }
            else {
                & $wrapperScriptBlock $parameters
            }
            # if the code reaches here we did not break
            #$break = $false
        } while ($false)
    }
    catch {
        $err = $_
    }

    if ($MoveBetweenScopes) {
        # switch-timer to framework scope inlined
        $state.UserCodeStopWatch.Stop()
        $state.FrameworkStopWatch.Start()

        if ($null -ne $OnFrameworkScopeTransition) {
            & $OnFrameworkScopeTransition
        }
    }

    if ($err) {
        $parameters.ErrorRecord.Add($err)
    }

    $r = [Pester.InvocationResult]::Create((0 -eq $parameters.ErrorRecord.Count), $parameters. ErrorRecord, $standardOutput)

    return $r
}

function Reset-TestSuiteTimer ($o) {

}

function Switch-Timer {
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Framework", "UserCode")]
        $Scope
    )

    # perf: optimizing away parameter and validate set, and $Scope as int or bool within an if, only brings about 1/3 saving (about 60 ms per 1000 calls)
    # not worth it for the moment
    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        if ($state.UserCodeStopWatch.IsRunning) {
            Write-PesterDebugMessage -Scope TimingCore "Switching from UserCode to $Scope"
        }

        if ($state.FrameworkStopWatch.IsRunning) {
            Write-PesterDebugMessage -Scope TimingCore "Switching from Framework to $Scope"
        }

        Write-PesterDebugMessage -Scope TimingCore -Message "UserCode total time $($state.UserCodeStopWatch.ElapsedMilliseconds)ms"
        Write-PesterDebugMessage -Scope TimingCore -Message "Framework total time $($state.FrameworkStopWatch.ElapsedMilliseconds)ms"
    }

    switch ($Scope) {
        "Framework" {
            # running in framework code adds time only to the overhead timer
            $state.UserCodeStopWatch.Stop()
            $state.FrameworkStopWatch.Start()
        }
        "UserCode" {
            $state.UserCodeStopWatch.Start()
            $state.FrameworkStopWatch.Stop()
        }
        default { throw [ArgumentException]"" }
    }
}

function Test-ShouldRun {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Item,
        $Filter
    )

    # see https://github.com/pester/Pester/issues/1442 for description of how this filtering works

    $result = @{
        Include  = $false
        Exclude  = $false
        Explicit = $false
    }

    $anyIncludeFilters = $false
    $fullDottedPath = $Item.Path -join "."
    if ($null -eq $Filter) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) is included, because there is no filters."
        }

        $result.Include = $true
        return $result
    }

    $parent = if ('Test' -eq $Item.ItemType) {
        $Item.Block
    }
    elseif ('Block' -eq $Item.ItemType) {
        # no need to check if we are root, we will not run these rules on Root block
        $Item.Parent
    }

    if ($parent.Exclude) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) is excluded, because it's parent is excluded."
        }
        $result.Exclude = $true
        return $result
    }

    # item is excluded when any of the exclude tags match
    $tagFilter = $Filter.ExcludeTag
    if ($tagFilter -and 0 -ne $tagFilter.Count) {
        foreach ($f in $tagFilter) {
            foreach ($t in $Item.Tag) {
                if ($t -like $f) {
                    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                        Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) is excluded, because it's tag '$t' matches exclude tag filter '$f'."
                    }
                    $result.Exclude = $true
                    return $result
                }
            }
        }
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) did not match the exclude tag filter, moving on to the next filter."
        }
    }

    $excludeLineFilter = $Filter.ExcludeLine

    $line = "$(if ($Item.ScriptBlock.File) { $Item.ScriptBlock.File } else { $Item.ScriptBlock.Id }):$($Item.StartLine)" -replace '\\', '/'
    if ($excludeLineFilter -and 0 -ne $excludeLineFilter.Count) {
        foreach ($l in $excludeLineFilter -replace '\\', '/') {
            if ($l -eq $line) {
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) is excluded, because its path:line '$line' matches line filter '$excludeLineFilter'."
                }
                $result.Exclude = $true
                $result.Explicit = $true
                return $result
            }
        }
    }

    # - place exclude filters above this line and include below this line

    $lineFilter = $Filter.Line
    # use File for saved files or Id for ScriptBlocks without files
    # this filter has the ability to set the test to "explicit" so we can run
    # the test even if it is marked as skipped run this include as first so we figure it out
    # in one place and check if parent was included after this one to short circuit the other
    # filters in case parent already knows that it will run

    $line = "$(if ($Item.ScriptBlock.File) { $Item.ScriptBlock.File } else { $Item.ScriptBlock.Id }):$($Item.StartLine)" -replace '\\', '/'
    if ($lineFilter -and 0 -ne $lineFilter.Count) {
        $anyIncludeFilters = $true
        foreach ($l in $lineFilter -replace '\\', '/') {
            if ($l -eq $line) {
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) is included, because its path:line '$line' matches line filter '$lineFilter'."
                    Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) is explicitly included, because it matched line filter, and will run even if -Skip is specified on it. Any skipped children will still be skipped."
                }

                $result.Explicit = $true
                $result.Include = $true
                return $result
            }
        }
    }

    if ($parent.Include) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) is included, because its parent is included."
        }

        $result.Include = $true
        return $result
    }

    # test is included when it has tags and the any of the tags match
    $tagFilter = $Filter.Tag
    if ($tagFilter -and 0 -ne $tagFilter.Count) {
        $anyIncludeFilters = $true
        if ($null -eq $Item.Tag -or 0 -eq $Item.Tag) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) has no tags, moving to next include filter."
            }
        }
        else {
            foreach ($f in $tagFilter) {
                foreach ($t in $Item.Tag) {
                    if ($t -like $f) {
                        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                            Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) is included, because it's tag '$t' matches tag filter '$f'."
                        }

                        $result.Include = $true
                        return $result
                    }
                }
            }
        }
    }

    $allPaths = $Filter.FullName
    if ($allPaths -and 0 -ne $allPaths) {
        $anyIncludeFilters = $true
        foreach ($p in $allPaths) {
            if ($fullDottedPath -like $p) {
                $include = $true
                break
            }
        }
        if ($include) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) is included, because it matches fullname filter '$include'."
            }

            $result.Include = $true
            return $result
        }
        else {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) does not match the dotted path filter, moving to next include filter."
            }
        }
    }

    if ($anyIncludeFilters) {
        if ('Test' -eq $Item.ItemType) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) did not match any of the include filters, it will not be included in the run."
            }
        }
        elseif ('Block' -eq $Item.ItemType) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) did not match any of the include filters, but it will still be included in the run, it's children will determine if it will run."
            }
        }
        else {
            throw "Item type $($Item.ItemType) is not supported in filter."
        }
    }
    else {
        if ('Test' -eq $Item.ItemType) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) will be included in the run, because there were no include filters so all tests are included unless they match exclude rule."
            }

            $result.Include = $true
        } # putting the bool in both to avoid string comparison
        elseif ('Block' -eq $Item.ItemType) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Filter "($fullDottedPath) $($Item.ItemType) will be included in the run, because there were no include filters, and will let its children to determine whether or not it should run."
            }
        }
        else {
            throw "Item type $($Item.ItemType) is not supported in filter."
        }

        return $result
    }

    return $result
}

function Invoke-Test {
    #[CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSObject[]] $BlockContainer,
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState,
        $Filter,
        $Plugin,
        $PluginConfiguration,
        $PluginData,
        $Configuration
    )

    # set the incoming value for all the child scopes
    # TODO: revisit this because this will probably act weird as we jump between session states
    $PesterPreference = $Configuration

    # PESTER_BUILD
    if ($null -eq $PesterPreference) {
        $Configuration = $PesterPreference = [PesterConfiguration]::Default
    }
    # end PESTER_BUILD

    # define the state if we don't have it yet, this will happen when we call this function directly
    # but normally the parent invoker (most often Invoke-Pester) will set the state. So we don't want to reset
    # it here.
    if (notDefined state) {
        $state = New-PesterState
    }

    $state.Plugin = $Plugin
    $state.PluginConfiguration = $PluginConfiguration
    $state.PluginData = $PluginData
    $state.Configuration = $Configuration

    # # TODO: this it potentially unreliable, because suppressed errors are written to Error as well. And the errors are captured only from the caller state. So let's use it only as a useful indicator during migration and see how it works in production code.

    # # finding if there were any non-terminating errors during the run, user can clear the array, and the array has fixed size so we can't just try to detect if there is any difference by counts before and after. So I capture the last known error in that state and try to find it in the array after the run
    # $originalErrors = $SessionState.PSVariable.Get("Error").Value
    # $originalLastError = $originalErrors[0]
    # $originalErrorCount = $originalErrors.Count

    $found = Discover-Test -BlockContainer $BlockContainer -Filter $Filter -SessionState $SessionState

    if ($PesterPreference.Run.SkipRun.Value) {
        foreach ($f in $found) {
            ConvertTo-DiscoveredBlockContainer -Block $f
        }

        return
    }
    # $errs = $SessionState.PSVariable.Get("Error").Value
    # $errsCount = $errs.Count
    # if ($errsCount -lt $originalErrorCount) {
    #     # it would be possible to detect that there are 0 errors, in the array and continue,
    #     # but this still indicates the user code is running where it should not, so let's throw anyway
    #     throw "Test discovery failed. The error count ($errsCount) after running discovery is lower than the error count before discovery ($originalErrorCount). Is some of your code running outside Pester controlled blocks and it clears the `$error array by calling `$error.Clear()?"

    # }


    # if ($originalErrorCount -lt $errsCount) {
    #     # probably the most usual case,  there are more errors then there were before,
    #     # so some were written to the screen, this also runs when the user cleared the
    #     # array and wrote more errors than there originally were
    #     $i = $errsCount - $originalErrorCount
    # }
    # else {
    #     # there is equal amount of errors, the array was probably full and so the original
    #     # error shifted towards the end of the array, we try to find it and see how many new
    #     # errors are there
    #     for ($i = 0 ; $i -lt $errsLength; $i++) {
    #         if ([object]::referenceEquals($errs[$i], $lastError)) {
    #             break
    #         }
    #     }
    # }
    # if (0 -ne $i) {
    #     throw "Test discovery failed. There were $i non-terminating errors during test discovery. This indicates that some of your code is invoked outside of Pester controlled blocks and fails. No tests will be run."
    # }
    Run-Test -Block $found -SessionState $SessionState
}

function PostProcess-DiscoveredBlock {
    param (
        [Parameter(Mandatory = $true)]
        $Block,
        $Filter,
        $BlockContainer,
        [Parameter(Mandatory = $true)]
        $RootBlock
    )

    # pass array of blocks rather than 1 block to cross the function boundary
    # as few times as we can
    foreach ($b in $Block) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            $path = $b.Path -join "."
        }

        # traverses the block structure after a block was found and
        # link childs to their parents, filter blocks and tests to
        # determine which should run, and mark blocks and tests
        # as first or last to know when one time setups & teardowns should run
        $b.IsRoot = $b -eq $RootBlock
        $b.Root = $RootBlock
        $b.BlockContainer = $BlockContainer

        $tests = $b.Tests

        if ($b.IsRoot) {
            $b.Explicit = $false
            $b.Exclude = $false
            $b.Include = $false
            $b.ShouldRun = $true
        }
        else {
            $shouldRun = (Test-ShouldRun -Item $b -Filter $Filter)
            $b.Explicit = $shouldRun.Explicit

            if (-not $shouldRun.Exclude -and -not $shouldRun.Include) {
                $b.ShouldRun = $true
            }
            elseif ($shouldRun.Include) {
                $b.ShouldRun = $true
            }
            elseif ($shouldRun.Exclude) {
                $b.ShouldRun = $false
            }
            else {
                throw "Unknown combination of include exclude $($shouldRun)"
            }

            $b.Include = $shouldRun.Include -and -not $shouldRun.Exclude
            $b.Exclude = $shouldRun.Exclude
        }

        $parentBlockIsSkipped = (-not $b.IsRoot -and $b.Parent.Skip)

        if ($b.Skip) {
            if ($b.Explicit) {
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Skip "($path) Block was marked as skipped, but will not be skipped because it was explicitly requested to run."
                }

                $b.Skip = $false
            }
            else {
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Skip "($path) Block is skipped."
                }

                $b.Skip = $true
            }
        }
        elseif ($parentBlockIsSkipped) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Skip "($path) Block is skipped because a parent block was skipped."
            }

            $b.Skip = $true
        }

        $blockShouldRun = $false
        $allTestsSkipped = $true
        if ($tests.Count -gt 0) {
            foreach ($t in $tests) {
                $t.Block = $b

                if ($t.Block.Exclude) {
                    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                        $path = $t.Path -join "."
                        Write-PesterDebugMessage -Scope Filter "($path) Test is excluded because parent block was excluded."
                    }
                    $t.ShouldRun = $false
                }
                else {
                    # run the exclude filters before checking if the parent is included
                    # otherwise you would include tests that could match the exclude rule
                    $shouldRun = (Test-ShouldRun -Item $t -Filter $Filter)
                    $t.Explicit = $shouldRun.Explicit

                    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                        $path = $t.Path -join "."
                    }

                    if (-not $shouldRun.Include -and -not $shouldRun.Exclude) {
                        $t.ShouldRun = $false
                    }
                    elseif ($shouldRun.Include) {
                        $t.ShouldRun = $true
                    }
                    elseif ($shouldRun.Exclude) {
                        $t.ShouldRun = $false
                    }
                    else {
                        throw "Unknown combination of ShouldRun $ShouldRun"
                    }
                }

                if ($t.Skip) {
                    if ($t.ShouldRun -and $t.Explicit) {
                        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                            Write-PesterDebugMessage -Scope Skip "($path) Test was marked as skipped, but will not be skipped because it was explicitly requested to run."
                        }

                        $t.Skip = $false
                    }
                    else {
                        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                            Write-PesterDebugMessage -Scope Skip "($path) Test is skipped."
                        }

                        $t.Skip = $true
                    }
                }
                elseif ($b.Skip) {
                    if ($t.ShouldRun -and $t.Explicit) {
                        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                            Write-PesterDebugMessage -Scope Skip "($path) Test was marked as skipped, because its parent was marked as skipped, but will not be skipped because it was explicitly requested to run."
                        }

                        $t.Skip = $false
                    }
                    else {
                        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                            Write-PesterDebugMessage -Scope Skip "($path) Test is skipped because a parent block was skipped."
                        }

                        $t.Skip = $true
                    }
                }
            }


            # if we determined that the block should run we can still make it not run if
            # none of it's children will run
            if ($b.ShouldRun) {
                $testsToRun = foreach ($t in $tests) { if ($t.ShouldRun) { $t } }
                if ($testsToRun -and 0 -ne $testsToRun.Count) {
                    $testsToRun[0].First = $true
                    $testsToRun[-1].Last = $true
                    $blockShouldRun = $true
                }

                foreach ($t in $testsToRun) {
                    if (-not $t.Skip) {
                        $allTestsSkipped = $false
                        break
                    }
                }
            }
        }

        $childBlocks = $b.Blocks
        $anyChildBlockShouldRun = $false
        $allChildBlockSkipped = $true
        if ($childBlocks.Count -gt 0) {
            foreach ($cb in $childBlocks) {
                $cb.Parent = $b
            }

            # passing the array as a whole to cross the function boundary as few times as I can
            PostProcess-DiscoveredBlock -Block $childBlocks -Filter $Filter -BlockContainer $BlockContainer -RootBlock $RootBlock

            $childBlocksToRun = foreach ($cb in $childBlocks) { if ($cb.ShouldRun) { $cb } }
            $anyChildBlockShouldRun = $childBlocksToRun -and 0 -ne $childBlocksToRun.Count
            if ($anyChildBlockShouldRun) {
                $childBlocksToRun[0].First = $true
                $childBlocksToRun[-1].Last = $true
            }

            foreach ($cb in $childBlocksToRun) {
                if (-not $cb.Skip) {
                    $allChildBlockSkipped = $false
                    break
                }
            }
        }

        $shouldRunBasedOnChildren = $blockShouldRun -or $anyChildBlockShouldRun
        $shouldSkipBasedOnChildren = $allTestsSkipped -and $allChildBlockSkipped

        if ($b.ShouldRun -and -not $shouldRunBasedOnChildren) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Filter "($($b.Path -join '.')) Block was marked as Should run based on filters, but none of its tests or tests in children blocks were marked as should run. So the block won't run."
            }
        }

        $b.ShouldRun = $shouldRunBasedOnChildren

        if ($b.ShouldRun) {
            if (-not $b.Skip -and $shouldSkipBasedOnChildren) {
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    if ($b.IsRoot) {
                        Write-PesterDebugMessage -Scope Skip "($($b.BlockContainer)) Container will be skipped because all included children are marked as skipped."
                    } else {
                        Write-PesterDebugMessage -Scope Skip "($($b.Path -join '.')) Block will be skipped because all included children are marked as skipped."
                    }
                }
                $b.Skip = $true
            } elseif ($b.Skip -and -not $shouldSkipBasedOnChildren) {
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Skip "($($b.Path -join '.')) Block was marked as skipped, but one or more children are explicitly requested to be run, so the block itself will not be skipped."
                }
                # This is done to execute setup and teardown before explicitly included tests, e.g. using line filter
                # Remaining children have already inherited block-level Skip earlier in this function as expected
                $b.Skip = $false
            }
        }
    }
}

function PostProcess-ExecutedBlock {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Block
    )


    # traverses the block structure after a block was executed and
    # and sets the failures correctly so the aggreagatted failures
    # propagate towards the root so if a child test fails it's block
    # aggregated result should be marked as failed

    process {
        foreach ($b in $Block) {
            $thisBlockFailed = -not $b.OwnPassed

            $b.OwnTotalCount = 0
            $b.OwnFailedCount = 0
            $b.OwnPassedCount = 0
            $b.OwnSkippedCount = 0
            $b.OwnInconclusiveCount = 0
            $b.OwnNotRunCount = 0

            $testDuration = [TimeSpan]::Zero

            foreach ($t in $b.Tests) {
                $testDuration += $t.Duration

                $b.OwnTotalCount++
                if (-not $t.ShouldRun) {
                    $b.OwnNotRunCount++
                }
                elseif ($t.ShouldRun -and $t.Inconclusive) {
                    $b.OwnInconclusiveCount++
                }
                elseif ($t.ShouldRun -and $t.Skipped) {
                    $b.OwnSkippedCount++
                }
                elseif (($t.Executed -and -not $t.Passed) -or ($t.ShouldRun -and -not $t.Executed)) {
                    # TODO:  this condition works but needs to be revisited. when the parent fails the test is marked as failed, because it should have run but it did not,and but there is no error in the test result, in such case all tests should probably add error or a flag that indicates that the parent failed, or a log or something, but error is probably the best
                    $b.OwnFailedCount++
                }
                elseif ($t.Executed -and $t.Passed) {
                    $b.OwnPassedCount++
                }
                else {
                    throw "Test '$($t.Name)' is in invalid state. $($t | Format-List -Force * | & $SafeCommands['Out-String'])"
                }
            }

            $anyTestFailed = 0 -lt $b.OwnFailedCount

            $childBlocks = $b.Blocks
            $anyChildBlockFailed = $false
            $aggregatedChildDuration = [TimeSpan]::Zero
            if (none $childBlocks) {
                # one thing to consider here is what happens when a block fails, in the current
                # execution model the block can fail when a setup or teardown fails, with failed
                # setup it is easy all the tests in the block are considered failed, with teardown
                # not so much, when all tests pass and the teardown itself fails what should be the result?



                # todo: there are two concepts mixed with the "own", because the duration and the test counts act differently. With the counting we are using own as "the count of the tests in this block", but with duration the "own" means "self", that is how long this block itself has run, without the tests. This information might not be important but this should be cleared up before shipping. Same goes with the relation to failure, ownPassed means that the block itself passed (that is no setup or teardown failed in it), even though the underlying tests might fail.


                $b.OwnDuration = $b.Duration - $testDuration

                $b.Passed = -not ($thisBlockFailed -or $anyTestFailed)

                # we have no child blocks so the own counts are the same as the total counts
                $b.TotalCount = $b.OwnTotalCount
                $b.FailedCount = $b.OwnFailedCount
                $b.PassedCount = $b.OwnPassedCount
                $b.SkippedCount = $b.OwnSkippedCount
                $b.InconclusiveCount = $b.OwnInconclusiveCount
                $b.NotRunCount = $b.OwnNotRunCount
            }
            else {
                # when we have children we first let them process themselves and
                # then we add the results together (the recursion could reach to the parent and add the totals)
                # but that is difficult with the duration, so this way is less error prone
                PostProcess-ExecutedBlock -Block $childBlocks

                foreach ($child in $childBlocks) {
                    # check that no child block failed, the Passed is aggregate failed, so it will be false
                    # when any test fails in the child, or if the block itself fails
                    if ($child.ShouldRun -and -not $child.Passed) {
                        $anyChildBlockFailed = $true
                    }

                    $aggregatedChildDuration += $child.Duration

                    $b.TotalCount += $child.TotalCount
                    $b.PassedCount += $child.PassedCount
                    $b.FailedCount += $child.FailedCount
                    $b.SkippedCount += $child.SkippedCount
                    $b.InconclusiveCount += $child.InconclusiveCount
                    $b.NotRunCount += $child.NotRunCount
                }

                # then we add counts from this block to the counts from the children blocks
                $b.TotalCount += $b.OwnTotalCount
                $b.PassedCount += $b.OwnPassedCount
                $b.FailedCount += $b.OwnFailedCount
                $b.SkippedCount += $b.OwnSkippedCount
                $b.InconclusiveCount += $b.OwnInconclusiveCount
                $b.NotRunCount += $b.OwnNotRunCount

                $b.Passed = -not ($thisBlockFailed -or $anyTestFailed -or $anyChildBlockFailed)
                $b.OwnDuration = $b.Duration - $testDuration - $aggregatedChildDuration
            }
        }
    }
}

function Where-Failed {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Block
    )

    $Block | View-Flat | & $SafeCommands['Where-Object'] { $_.ShouldRun -and (-not $_.Executed -or -not $_.Passed) }
}

function New-FilterObject {
    [CmdletBinding()]
    param (
        [String[]] $FullName,
        [String[]] $Tag,
        [String[]] $ExcludeTag,
        [String[]] $Line,
        [String[]] $ExcludeLine
    )

    [PSCustomObject] @{
        FullName    = $FullName
        Tag         = $Tag
        ExcludeTag  = $ExcludeTag
        Line        = $Line
        ExcludeLine = $ExcludeLine
    }
}

function New-PluginObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String] $Name,
        [Hashtable] $Configuration,
        [ScriptBlock] $Start,
        [ScriptBlock] $DiscoveryStart,
        [ScriptBlock] $ContainerDiscoveryStart,
        [ScriptBlock] $BlockDiscoveryStart,
        [ScriptBlock] $TestDiscoveryStart,
        [ScriptBlock] $TestDiscoveryEnd,
        [ScriptBlock] $BlockDiscoveryEnd,
        [ScriptBlock] $ContainerDiscoveryEnd,
        [ScriptBlock] $DiscoveryEnd,
        [ScriptBlock] $RunStart,
        [scriptblock] $ContainerRunStart,
        [ScriptBlock] $OneTimeBlockSetupStart,
        [ScriptBlock] $EachBlockSetupStart,
        [ScriptBlock] $OneTimeTestSetupStart,
        [ScriptBlock] $EachTestSetupStart,
        [ScriptBlock] $EachTestTeardownEnd,
        [ScriptBlock] $OneTimeTestTeardownEnd,
        [ScriptBlock] $EachBlockTeardownEnd,
        [ScriptBlock] $OneTimeBlockTeardownEnd,
        [ScriptBlock] $ContainerRunEnd,
        [ScriptBlock] $RunEnd,
        [ScriptBlock] $End
    )

    [PSCustomObject] @{
        Name                    = $Name
        Configuration           = $Configuration
        Start                   = $Start
        DiscoveryStart          = $DiscoveryStart
        ContainerDiscoveryStart = $ContainerDiscoveryStart
        BlockDiscoveryStart     = $BlockDiscoveryStart
        TestDiscoveryStart      = $TestDiscoveryStart
        TestDiscoveryEnd        = $TestDiscoveryEnd
        BlockDiscoveryEnd       = $BlockDiscoveryEnd
        ContainerDiscoveryEnd   = $ContainerDiscoveryEnd
        DiscoveryEnd            = $DiscoveryEnd
        RunStart                = $RunStart
        ContainerRunStart       = $ContainerRunStart
        OneTimeBlockSetupStart  = $OneTimeBlockSetupStart
        EachBlockSetupStart     = $EachBlockSetupStart
        OneTimeTestSetupStart   = $OneTimeTestSetupStart
        EachTestSetupStart      = $EachTestSetupStart
        EachTestTeardownEnd     = $EachTestTeardownEnd
        OneTimeTestTeardownEnd  = $OneTimeTestTeardownEnd
        EachBlockTeardownEnd    = $EachBlockTeardownEnd
        OneTimeBlockTeardownEnd = $OneTimeBlockTeardownEnd
        ContainerRunEnd         = $ContainerRunEnd
        RunEnd                  = $RunEnd
        End                     = $End
        PSTypeName              = 'Plugin'
    }
}

function Invoke-BlockContainer {
    param (
        [Parameter(Mandatory)]
        $BlockContainer,
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState
    )

    if ($null -ne $BlockContainer.Data -and 0 -lt $BlockContainer.Data.Count) {
        foreach ($d in $BlockContainer.Data) {
            switch ($BlockContainer.Type) {
                "ScriptBlock" {
                    Invoke-InNewScriptScope -ScriptBlock { & $BlockContainer.Item @d } -SessionState $SessionState
                }
                "File" { Invoke-File -Path $BlockContainer.Item.PSPath -SessionState $SessionState -Data $d }
                default { throw [System.ArgumentOutOfRangeException]"" }
            }
        }
    }
    else {
        switch ($BlockContainer.Type) {
            "ScriptBlock" {
                Invoke-InNewScriptScope -ScriptBlock { & $BlockContainer.Item } -SessionState $SessionState
            }
            "File" { Invoke-File -Path $BlockContainer.Item.PSPath -SessionState $SessionState }
            default { throw [System.ArgumentOutOfRangeException]"" }
        }
    }
}

function New-BlockContainerObject {
    [OutputType([Pester.ContainerInfo])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ParameterSetName = 'ScriptBlock')]
        [ScriptBlock] $ScriptBlock,

        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [String] $Path,

        [Parameter(Mandatory, ParameterSetName = 'File')]
        [System.IO.FileInfo] $File,

        [Parameter(Mandatory, ParameterSetName = 'Container')]
        [Pester.ContainerInfo] $Container,

        $Data
    )

    # Data is null or IDictionary, but all IDictionary does not work with ContainsKey()
    # Contains() requires interface-casting for some types, ex. generic dictionary.
    # Instead we're merging to a controlled data structure to have consistent API internally
    # Also works as a shallow clone to avoid leaking default parameter values between containers with same Data
    $ContainerData = @{ }
    if ($Data -is [System.Collections.IDictionary]) {
        Merge-Hashtable -Destination $ContainerData -Source $Data
    }

    $type, $item = switch ($PSCmdlet.ParameterSetName) {
        'ScriptBlock' { 'ScriptBlock', $ScriptBlock }
        'Path' { 'File', (& $SafeCommands['Get-Item'] $Path) }
        'File' { 'File', $File }
        'Container' { $Container.Type, $Container.Item }
        default { throw [System.ArgumentOutOfRangeException]'' }
    }

    if ($item -is [scriptblock]) {
        Assert-BoundScriptBlockInput -ScriptBlock $item
    }

    $c = [Pester.ContainerInfo]::Create()
    $c.Type = $type
    $c.Item = $item
    $c.Data = $ContainerData
    $c
}

function New-DiscoveredBlockContainerObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $BlockContainer,
        [Parameter(Mandatory)]
        $Block
    )

    [PSCustomObject] @{
        Type   = $BlockContainer.Type
        Item   = $BlockContainer.Item
        # I create a Root block to keep the discovery unaware of containers,
        # but I don't want to publish that root block because it contains properties
        # that do not make sense on container level like Name and Parent,
        # so here we don't want to take the root block but the blocks inside of it
        # and copy the rest of the meaningful properties
        Blocks = $Block.Blocks
    }
}

function Invoke-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]
        $Path,
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState,
        [Collections.IDictionary] $Data = @{}
    )

    $sb = {
        param ($private:p, $private:d)
        . $private:p @d
    }

    # set the original session state to the wrapper scriptblock
    # making it invoke in the caller session state
    # TODO: heat this up if we want to keep the first test running accuately
    $SessionStateInternal = $script:SessionStateInternalProperty.GetValue($SessionState, $null)
    $script:ScriptBlockSessionStateInternalProperty.SetValue($sb, $SessionStateInternal, $null)

    & $sb $Path $Data
}

function New-ParametrizedTest () {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String] $Name,
        [Parameter(Mandatory = $true, Position = 1)]
        [ScriptBlock] $ScriptBlock,
        [int] $StartLine = $MyInvocation.ScriptLineNumber,
        [int] $StartColumn = $MyInvocation.OffsetInLine,
        [String[]] $Tag = @(),
        # do not use [hashtable[]] because that throws away the order if user uses [ordered] hashtable
        [object[]] $Data,
        [Switch] $Focus,
        [Switch] $Skip
    )

    # using the position of It as Id for the the test so we can join multiple testcases together, this should be unique enough because it only needs to be unique for the current block.
    # TODO: Id is used by NUnit2.5 and 3 testresults to group. A better way to solve this?
    $groupId = "${StartLine}:${StartColumn}"
    foreach ($d in $Data) {
        New-Test -GroupId $groupId -Name $Name -Tag $Tag -ScriptBlock $ScriptBlock -StartLine $StartLine -Data $d -Focus:$Focus -Skip:$Skip
    }
}

function Invoke-InNewScriptScope ([ScriptBlock] $ScriptBlock, $SessionState) {
    # running in a script file will push a new script scope up the stack in the provided
    # session state. To do this from a module we need to transport the file invocation into the
    # correct session state, and then invoke the file. We can also pass a script block tied
    # to the current module to invoke internal function in the newly pushed script scope.

    $Path = "$PSScriptRoot/Pester.ps1"
    $Data = @{ ScriptBlock = $ScriptBlock }

    $wrapper = {
        param ($private:p, $private:d)
        & $private:p @d
    }

    # set the original session state to the wrapper scriptblock
    $script:SessionStateInternal = $SessionStateInternalProperty.GetValue($SessionState, $null)
    $script:ScriptBlockSessionStateInternalProperty.SetValue($wrapper, $SessionStateInternal, $null)

    . $wrapper $Path $Data
}

function Add-MissingContainerParameters ($RootBlock, $Container, $CallingFunction) {
    # Adds default values for container parameters not provided by the user.
    # Also adds real parameter name as variable in Run-phase when alias was used, just like normal PowerShell will.

    # Using AST to get parameter-names as $PSCmdLet.MyInvocation.MyCommand only works for advanced functions/scripts/cmdlets.
    # No need to filter on parameter sets OR whether default values are set because Powershell adds all parameters (not aliases) as variables
    # with default value or $null if not specified (probably to avoid error caused by inheritance).
    $Ast = switch ($Container.Type) {
        "ScriptBlock" { $container.Item.Ast }
        "File" {
            $externalScriptInfo = $CallingFunction.SessionState.InvokeCommand.GetCommand($Container.Item.PSPath, [System.Management.Automation.CommandTypes]::ExternalScript)
            $externalScriptInfo.ScriptBlock.Ast
        }
        default { throw [System.ArgumentOutOfRangeException]"" }
    }

    if ($null -ne $Ast -and $null -ne $Ast.ParamBlock -and $Ast.ParamBlock.Parameters.Count -gt 0) {
        $parametersToCheck = foreach ($param in $Ast.ParamBlock.Parameters) { $param.Name.VariablePath.UserPath }

        foreach ($param in $parametersToCheck) {
            $v = $CallingFunction.SessionState.PSVariable.Get($param)
            if ((-not $RootBlock.Data.ContainsKey($param)) -and $v) {
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Runtime "Container parameter '$param' is undefined, adding to container Data with default value $(Format-Nicely $v.Value)."
                }
                $RootBlock.Data.Add($param, $v.Value)
            }
        }
    }

    $RootBlock.FrameworkData.MissingParametersProcessed = $true
}

function Assert-BoundScriptBlockInput {
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )
    $internalSessionState = $script:ScriptBlockSessionStateInternalProperty.GetValue($ScriptBlock, $null)
    if ($null -eq $internalSessionState) {
        $maxLength = 250
        $prettySb = (Format-Nicely2 $ScriptBlock) -replace '\s{2,}', ' '
        if ($prettySb.Length -gt $maxLength) {
            $prettySb = "$($prettySb.Remove($maxLength))..."
        }

        throw [System.ArgumentException]::new("Unbound scriptblock is not allowed, because it would run inside of Pester session state and produce unexpected results. See https://github.com/pester/Pester/issues/2411 for more details and workarounds. ScriptBlock: '$prettySb'")
    }
}
