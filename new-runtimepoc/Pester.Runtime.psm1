Import-Module $PSScriptRoot\Pester.Utility.psm1 -DisableNameChecking

$state = [PSCustomObject] @{
    # indicate whether or not we are currently
    # running in discovery mode se we can change
    # behavior of the commands appropriately
    Discovery          = $false

    CurrentBlock       = $null
    CurrentTest        = $null

    Plugin             = $null

    TotalStopWatch     = $null
    TestStopWatch      = $null
    BlockStopWatch     = $null
    FrameworkStopWatch = $null
}


function Reset-TestSuiteState {
    # resets the module state to the default
    Write-PesterDebugMessage -Scope Runtime "Resetting all state to default."
    $state.Discovery = $false

    $state.Plugin = $null

    $state.CurrentBlock = $null
    $state.CurrentTest = $null
    Reset-Scope
    Reset-TestSuiteTimer
}

function Reset-PerContainerState {
    param(
        [Parameter(Mandatory = $true)]
        [PSTypeName("DiscoveredBlock")] $RootBlock
    )
    Write-PesterDebugMessage -Scope Runtime "Resetting per container state."
    $state.CurrentBlock = $RootBlock
    Reset-Scope
}

# compatibility
function Test-NullOrWhiteSpace ($Value) {
    # psv2 compatibility, on newer .net we would simply use
    # [string]::isnullorwhitespace
    $null -eq $Value -or $Value -match "^\s*$"
}

function New_PSObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [HashTable] $Property,
        [String] $Type
    )

    if (-not (Test-NullOrWhiteSpace $Type) -and -not $Property.ContainsKey($Type)) {
        $Property.Add("PSTypeName", $Type)
    }

    New-Object -Type PSObject -Property $Property
}

function Find-Test {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSTypeName("BlockContainer")][PSObject[]] $BlockContainer,
        [PSTypeName("Filter")] $Filter,
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState
    )
    Write-PesterDebugMessage -Scope Discovery "Running just discovery."
    $found = Discover-Test -BlockContainer $BlockContainer -Filter $Filter -SessionState $SessionState

    foreach ($f in $found) {
        ConvertTo-DiscoveredBlockContainer -Block $f
    }
}

function ConvertTo-DiscoveredBlockContainer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSTypeName("DiscoveredBlock")] $Block
    )

    # takes a root block and converts it to a discovered block container
    # that we can publish from Find-Test, because keeping everything a block makes the internal
    # code simpler
    $container = $Block.BlockContainer
    $content = tryGetProperty $container Content
    $type = tryGetProperty $container Type

    # TODO: Add other properties that are relevant to found tests
    $b = $Block | Select -ExcludeProperty @(
        "Parent"
        "Name"
        "Tag"
        "First"
        "Last"
        "StandardOutput"
        "Passed"
        "Executed"
        "Path",
        "StartedAt",
        "Duration",
        "Aggregated*"
    ) -Property @(
        @{n = "Content"; e = {$content}}
        @{n = "Type"; e = {$type}},
        @{n = "PSTypename"; e = {"DiscoveredBlockContainer"}}
        '*'
    )

    $b
}

function ConvertTo-ExecutedBlockContainer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSTypeName("DiscoveredBlock")] $Block
    )

    # takes a root block and converts it to a executed block container
    # that we can publish from Invoke-Test, because keeping everything a block makes the internal
    # code simpler
    $container = $Block.BlockContainer
    $content = tryGetProperty $container Content
    $type = tryGetProperty $container Type

    $b = $Block | Select -ExcludeProperty @(
        "Parent"
        "Name"
        "Tag"
        "First"
        "Last"
        "StandardOutput"
        "Path"
    ) -Property @(
        @{n = "Content"; e = {$content}}
        @{n = "Type"; e = {$type}},
        @{n = "PSTypename"; e = {"ExecutedBlockContainer"}}
        '*'
    )

    $b
}


# endpoint for adding a block that contains tests
# or other blocks
function New-Block {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String] $Name,
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock,
        [String[]] $Tag = @(),
        # TODO: rename to FrameworkData to avoid confusion with Data (on TestObject)? but first look at how we use it, and if it makes sense
        [HashTable] $FrameworkData = @{}
    )

    Switch-Timer -Scope Framework
    $blockStartTime = $state.BlockStopWatch.Elapsed
    $overheadStartTime = $state.FrameworkStopWatch.Elapsed

    Push-Scope -Scope (New-Scope -Name $Name -Hint Block)
    $path = Get-ScopeHistory | % Name
    Write-PesterDebugMessage -Scope Runtime "Entering path $($path -join '.')"

    $block = $null

    if (Is-Discovery) {
        Write-PesterDebugMessage -Scope Discovery "Adding block $Name to discovered blocks"
        $block = New-BlockObject -Name $Name -Path $path -Tag $Tag -ScriptBlock $ScriptBlock -FrameworkData $FrameworkData
        # we attach the current block to the parent
        Add-Block -Block $block
    }

    $previousBlock = Get-CurrentBlock
    if ($null -eq $block) {
        $block = Find-CurrentBlock -Name $Name -ScriptBlock $ScriptBlock
    }

    Set-CurrentBlock -Block $block

    try {
        if (Is-Discovery) {
            Write-PesterDebugMessage -Scope Discovery "Discovering in body of block $Name"
            & $ScriptBlock
            Write-PesterDebugMessage -Scope Discovery "Finished discovering in body of block $Name"
        }
        else {
            if (-not $block.ShouldRun) {
                Write-PesterDebugMessage -Scope Runtime "Block is excluded from run, returning"
                return
            }
            Write-PesterDebugMessage -Scope Runtime "Executing body of block $Name"

            # TODO: no callbacks are provided because we are not transitioning between any states,
            # it might be nice to add a parameter to indicate that we run in the same scope
            # so we can avoid getting and setting the scope on scriptblock that already has that
            # scope, which is _potentially_ slow because of reflection, it would also allow
            # making the transition callbacks mandatory unless the parameter is provided
            $frameworkSetupResult = Invoke-ScriptBlock `
                -OuterSetup @(
                if ($block.First) { $state.Plugin.OneTimeBlockSetup | selectNonNull }
            ) `
                -Setup @( $state.Plugin.EachBlockSetup | selectNonNull ) `
                -ScriptBlock {} `
                -Context @{
                Context = @{
                    # context that is visible to plugins
                    Block = $block
                    Test  = $null
                }
            }

            if ($frameworkSetupResult.Success) {
                $result = Invoke-ScriptBlock `
                    -ScriptBlock $ScriptBlock `
                    -OuterSetup $( if (-not (Is-Discovery)) {
                        combineNonNull @(
                            $previousBlock.EachBlockSetup
                            $block.OneTimeTestSetup
                        )
                    }) `
                    -OuterTeardown $( if (-not (Is-Discovery)) {
                        combineNonNull @(
                            $block.OneTimeTestTeardown
                            $previousBlock.EachBlockTeardown
                        )
                    } ) `
                    -Context @{
                    # context that is visible in user code
                    Context = $block | Select -Property Name
                } `
                    -ReduceContextToInnerScope `
                    -OnUserScopeTransition { Switch-Timer -Scope Block } `
                    -OnFrameworkScopeTransition { Switch-Timer -Scope Framework }

                $block.Executed = $true
                $block.Passed = $result.Success
                $block.StandardOutput = $result.StandardOutput

                $block.ErrorRecord = $result.ErrorRecord
                Write-PesterDebugMessage -Scope Runtime "Finished executing body of block $Name"
            }

            $frameworkEachBlockTeardowns = @( $state.Plugin.EachBlockTeardown | selectNonNull )
            $frameworkOneTimeBlockTeardowns = @( if ($block.Last) { $state.Plugin.OneTimeBlockTeardown | selectNonNull } )
            # reverse the teardowns so they run in opposite order to setups
            [Array]::Reverse($frameworkEachBlockTeardowns)
            [Array]::Reverse($frameworkOneTimeBlockTeardowns)

            $frameworkTeardownResult = Invoke-ScriptBlock `
                -ScriptBlock {} `
                -Teardown $frameworkEachBlockTeardowns `
                -OuterTeardown $frameworkOneTimeBlockTeardowns `
                -Context @{
                Context = @{
                    # context that is visible to plugins
                    Block = $block
                    Test  = $null
                }
            }


            if (-not $frameworkSetupResult.Success -or -not $frameworkTeardownResult.Success) {
                & { # report framework failure
                    $ErrorActionPreference = 'Continue'
                    if ($frameworkSetupResult.ErrorRecord) {
                        foreach ($e in $frameworkSetupResult.ErrorRecord) {
                            Write-Host -ForegroundColor Red ($e | out-string)
                            Write-Host -ForegroundColor Red ($e.ScriptStackTrace | out-string)
                        }
                    }
                    if ($frameworkTeardownResult.ErrorRecord) {
                        foreach ($e in $frameworkTeardownResult.ErrorRecord) {
                            Write-Host -ForegroundColor Red ($e | out-string)
                            Write-Host -ForegroundColor Red ($e.ScriptStackTrace | out-string)
                        }
                    }

                    throw "framework fail"
                }
            }
        }
    }
    finally {
        $block.Duration = $state.BlockStopWatch.Elapsed - $blockStartTime
        $block.FrameworkDuration = $state.FrameworkStopWatch.Elapsed - $overheadStartTime
        Write-PesterDebugMessage -Scope Runtime "Leaving path $($path -join '.')"
        Set-CurrentBlock -Block $previousBlock
        $null = Pop-Scope
        Write-PesterDebugMessage -Scope Runtime "Left block $Name"
    }
}

# endpoint for adding a test
function New-Test {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String] $Name,
        [Parameter(Mandatory = $true, Position = 1)]
        [ScriptBlock] $ScriptBlock,
        [String[]] $Tag = @(),
        [HashTable] $Data = @{},
        [String] $Id,
        [Switch] $Focus
    )

    Switch-Timer -Scope Framework
    $testStartTime = $state.TestStopWatch.Elapsed
    $overheadStartTime = $state.FrameworkStopWatch.Elapsed

    Write-PesterDebugMessage -Scope Runtime "Entering test $Name"
    Push-Scope -Scope (New-Scope -Name $Name -Hint Test)
    try {
        $path = Get-ScopeHistory | % Name
        Write-PesterDebugMessage -Scope Runtime "Entering path $($path -join '.')"

        # do this setup when we are running discovery
        if (Is-Discovery) {
            $test = New-TestObject -Name $Name -ScriptBlock $ScriptBlock -Tag $Tag -Data $Data -Id $Id -Path $path -Focus:$Focus
            $test.FrameworkData.Runtime.Phase = 'Discovery'
            Add-Test -Test $test
            Write-PesterDebugMessage -Scope Discovery "Added test '$Name'"
        }
        else {
            $test = Find-CurrentTest -Name $Name -ScriptBlock $ScriptBlock -Id $Id
            $test.FrameworkData.Runtime.Phase = 'Execution'
            Set-CurrentTest -Test $test

            if (-not $test.ShouldRun) {
                Write-PesterDebugMessage -Scope Runtime "Test is excluded from run, returning"
                return
            }

            # TODO: overwrite the data captured during discovery with the data,
            # captured during execution, to make time sensitive data closer to the execution
            # this should be a good choice because even though the data should not generally change
            # when we for example do @{ Time = (Get-Date) } or load some counter, we should get the
            # data from the moment of execution, not from the moment of test discovery, which can
            # potentially be few seconds earlier. This also means that we should never identify tests
            # based on their names + data because the data can change. And also that we should not show
            # the data from the discovery when execution will follow (so it's not just a call to Find-Test)
            # This choice might need to be revisited
            $test.Data = $Data

            $block = Get-CurrentBlock

            Write-PesterDebugMessage -Scope Runtime "Running test '$Name'."
            # TODO: no callbacks are provided because we are not transitioning between any states,
            # it might be nice to add a parameter to indicate that we run in the same scope
            # so we can avoid getting and setting the scope on scriptblock that already has that
            # scope, which is _potentially_ slow because of reflection, it would also allow
            # making the transition callbacks mandatory unless the parameter is provided
            $frameworkSetupResult = Invoke-ScriptBlock `
                -OuterSetup @(
                if ($test.First) { $state.Plugin.OneTimeTestSetup | selectNonNull }
            ) `
                -Setup @( $state.Plugin.EachTestSetup | selectNonNull ) `
                -ScriptBlock {} `
                -Context @{
                Context = @{
                    # context visible to Plugins
                    Block = $block
                    Test  = $test
                }
            }

            if ($frameworkSetupResult.Success) {
                # invokes the body of the test
                $testInfo = $Test | Select -Property Name, Path
                # user provided data are merged with Pester provided context
                # TODO: use PesterContext as the name, or some other better reserved name to avoid conflicts
                $context = @{
                    # context visible in test
                    Context = $testInfo
                }
                Merge-Hashtable -Source $test.Data -Destination $context

                $eachTestSetups = CombineNonNull (Recurse-Up $Block { param ($b) $b.EachTestSetup } )
                $eachTestTeardowns = CombineNonNull (Recurse-Up $Block { param ($b) $b.EachTestTeardown } )

                $result = Invoke-ScriptBlock `
                    -Setup @(
                    if (any $eachTestSetups) {
                        # we collect the child first but want the parent to run first
                        [Array]::Reverse($eachTestSetups)
                        @( { $test.FrameworkData.Runtime.ExecutionStep = 'EachTestSetup' }) + @($eachTestSetups)
                    }
                    # setting the execution info here so I don't have to invoke change the
                    # contract of Invoke-ScriptBlock to accept multiple -ScriptBlock, because
                    # that is not needed, and would complicate figuring out in which session
                    # state we should run.
                    # this should run every time.
                    { $test.FrameworkData.Runtime.ExecutionStep = 'Test' }
                ) `
                    -ScriptBlock $ScriptBlock `
                    -Teardown @(
                    if (any $eachTestTeardowns) {
                        @( { $test.FrameworkData.Runtime.ExecutionStep = 'EachTestTeardown' }) + @($eachTestTeardowns)
                    } ) `
                    -Context $context `
                    -ReduceContextToInnerScope `
                    -OnUserScopeTransition { Switch-Timer -Scope Test } `
                    -OnFrameworkScopeTransition { Switch-Timer -Scope Framework } `
                    -NoNewScope

                $test.FrameworkData.Runtime.ExecutionStep = 'Finished'
                $test.Executed = $true
                $test.Passed = $result.Success
                $test.StandardOutput = $result.StandardOutput
                $test.ErrorRecord = $result.ErrorRecord

                $test.Duration = $state.TestStopWatch.Elapsed - $testStartTime
                $test.FrameworkDuration = $state.FrameworkStopWatch.Elapsed - $overheadStartTime
            }

            $frameworkTeardownResult = Invoke-ScriptBlock `
                -ScriptBlock {} `
                -Teardown @( $state.Plugin.EachTestTeardown | selectNonNull ) `
                -OuterTeardown @(
                if ($test.Last) { $state.Plugin.OneTimeTestTeardown | selectNonNull }
            ) `
                -Context @{
                Context = @{
                    # context visible to Plugins
                    Test  = $test
                    Block = $block
                }
            }

            if (-not $frameworkTeardownResult.Success -or -not $frameworkTeardownResult.Success) {
                throw $frameworkTeardownResult.ErrorRecord[-1]
            }
        }
    }
    finally {
        Write-PesterDebugMessage -Scope Runtime "Leaving path $($path -join '.')"
        $state.CurrentTest = $null
        $null = Pop-Scope
        Write-PesterDebugMessage -Scope Runtime "Left test $Name"
    }
}

# endpoint for adding a setup for each test in the block
function New-EachTestSetup {
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )

    if (Is-Discovery) {
        (Get-CurrentBlock).EachTestSetup = $ScriptBlock
    }
}

# endpoint for adding a teardown for each test in the block
function New-EachTestTeardown {
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )

    if (Is-Discovery) {
        (Get-CurrentBlock).EachTestTeardown = $ScriptBlock
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
        (Get-CurrentBlock).OneTimeTestSetup = $ScriptBlock
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
        (Get-CurrentBlock).OneTimeTestTeardown = $ScriptBlock
    }
}

# endpoint for adding a setup for each block in the current block
function New-EachBlockSetup {
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )
    if (Is-Discovery) {
        (Get-CurrentBlock).EachBlockSetup = $ScriptBlock
    }
}

# endpoint for adding a teardown for each block in the current block
function New-EachBlockTeardown {
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )
    if (Is-Discovery) {
        (Get-CurrentBlock).EachBlockTeardown = $ScriptBlock
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
        (Get-CurrentBlock).OneTimeBlockSetup = $ScriptBlock
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
        (Get-CurrentBlock).OneTimeBlockTeardown = $ScriptBlock
    }
}

function Get-CurrentBlock {
    [CmdletBinding()]
    param ( )
    $state.CurrentBlock
}

function Get-CurrentTest {
    [CmdletBinding()]
    param ( )
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

function Add-Test {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSTypeName("DiscoveredTest")]
        $Test
    )

    (Get-CurrentBlock).Tests += $Test
}

function New-TestObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String] $Name,
        [String[]] $Path,
        [String[]] $Tag,
        [HashTable] $Data,
        [String] $Id,
        [ScriptBlock] $ScriptBlock,
        [Switch] $Focus
    )

    New_PSObject -Type DiscoveredTest @{
        Name              = $Name
        Path              = $Path
        Tag               = $Tag
        Focus             = [Bool]$Focus
        Data              = $Data
        Executed          = $false
        Passed            = $false
        StandardOutput    = $null
        ErrorRecord       = @()
        First             = $false
        Last              = $false
        ShouldRun         = $false
        Duration          = [timespan]::Zero
        FrameworkDuration = [timespan]::Zero
        Id                = $Id
        ScriptBlock       = $ScriptBlock
        PluginData        = @{}
        FrameworkData     = @{
            Runtime = @{
                Phase         = $null
                ExecutionStep = $null
            }
        }
    }
}

function New-BlockObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String] $Name,
        [string[]] $Path,
        [string[]] $Tag,
        [ScriptBlock] $ScriptBlock,
        [HashTable] $FrameworkData = @{}
    )

    New_PSObject -Type DiscoveredBlock @{
        Name                 = $Name
        Path                 = $Path
        Tag                  = $Tag
        ScriptBlock          = $ScriptBlock
        FrameworkData        = $FrameworkData
        Tests                = @()
        BlockContainer       = $null
        Root                 = $null
        IsRoot               = $null
        Parent               = $null
        EachTestSetup        = $null
        OneTimeTestSetup     = $null
        EachTestTeardown     = $null
        OneTimeTestTeardown  = $null
        EachBlockSetup       = $null
        OneTimeBlockSetup    = $null
        EachBlockTeardown    = $null
        OneTimeBlockTeardown = $null
        Blocks               = @()
        Executed             = $false
        Passed               = $false
        First                = $false
        Last                 = $false
        StandardOutput       = $null
        ErrorRecord          = @()
        ShouldRun            = $false
        ExecutedAt           = $null
        Duration             = [timespan]::Zero
        FrameworkDuration    = [timespan]::Zero
        AggregatedDuration   = [timespan]::Zero
        AggregatedPassed     = $false
        PluginData           = @{}
    }
}

function Add-Block {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSTypeName("DiscoveredBlock")]
        $Block
    )

    $currentBlock = (Get-CurrentBlock)
    $Block.Parent = $currentBlock
    $currentBlock.Blocks += $Block
}

function Is-Discovery {
    $state.Discovery
}

function Discover-Test {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSTypeName("BlockContainer")][PSObject[]] $BlockContainer,
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState,
        $Filter
    )
    Write-PesterDebugMessage -Scope Discovery -Message "Starting test discovery in $(@($BlockContainer).Length) test containers."

    $state.Discovery = $true
    $found = foreach ($container in $BlockContainer) {
        Write-PesterDebugMessage -Scope Discovery "Discovering tests in $($container.Content)"
        # this is a block object that we add so we can capture
        # OneTime* and Each* setups, and capture multiple blocks in a
        # container
        $root = New-BlockObject -Name "Root"
        Reset-PerContainerState -RootBlock $root

        $null = Invoke-BlockContainer -BlockContainer $container -SessionState $SessionState

        [PSCustomObject]@{
            Container = $container
            Block     = $root
        }
        Write-PesterDebugMessage -Scope Discovery -LazyMessage { "Found $(@(View-Flat -Block $root).Count) tests" }
        Write-PesterDebugMessage -Scope Discovery "Discovery done in this container."
    }

    Write-PesterDebugMessage -Scope Discovery "Processing discovery result objects, to set root, parents, filters etc."

    # if any tests in the suite have -Focus parameter then all filters are disregarded
    # and only those tests should run
    $focused = [System.Collections.Generic.List[Object]]@()
    foreach ($f in $found) {
        Fold-Container -Container $f.Block -OnTest { param($t) if ($t.Focus) { $focused.Add($t.Path) } }
    }

    if (any $focused) {
        Write-PesterDebugMessage -Scope Discovery "There are some ($($focused.Count)) focused tests '$($(foreach ($p in $focused) { $p -join "." }) -join ",")' running just them."
        $Filter = New-FilterObject -Path $focused
    }

    foreach ($f in $found) {
        PostProcess-DiscoveredBlock -Block $f.Block -Filter $Filter -BlockContainer $f.Container
        $f.Block
    }

    Write-PesterDebugMessage -Scope Discovery "Test discovery finished."
}

function Run-Test {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSTypeName("DiscoveredBlock")][PSObject[]] $Block,
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState
    )

    $state.Discovery = $false
    # TODO: add where $true -eq $_.ShouldRun to execute only containers that have something to run
    foreach ($rootBlock in $Block) {
        if (-not $rootBlock.ShouldRun) {
            ConvertTo-ExecutedBlockContainer -Block $rootBlock
            continue
        }

        Reset-PerContainerState -RootBlock $rootBlock
        Switch-Timer -Scope Framework
        $blockStartTime = $state.BlockStopWatch.Elapsed
        $overheadStartTime = $state.FrameworkStopWatch.Elapsed

        $null = Invoke-BlockContainer -BlockContainer $rootBlock.BlockContainer -SessionState $SessionState

        $rootBlock.Duration = $state.BlockStopWatch.Elapsed - $blockStartTime
        $rootBlock.FrameworkDuration = $state.FrameworkStopWatch.Elapsed - $overheadStartTime
        PostProcess-ExecutedBlock -Block $rootBlock

        ConvertTo-ExecutedBlockContainer -Block $rootBlock
    }
}

function Invoke-ScriptBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ScriptBlock] $ScriptBlock,
        [ScriptBlock[]] $OuterSetup,
        [ScriptBlock[]] $Setup,
        [ScriptBlock[]] $Teardown,
        [ScriptBlock[]] $OuterTeardown,
        $Context = @{},
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
        [ScriptBlock] $OnUserScopeTransition = {},
        [ScriptBlock] $OnFrameworkScopeTransition = {}
    )

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

    # a similar solution was $SessionState.PSVariable.Set('a', 10)
    # but that sets the variable for all "scopes" in the current
    # scope so the value persist after the original has run which
    # is not correct,

    $wrapperScriptBlock = {
        # THIS RUNS (MOST OF THE TIME) IN USER SCOPE, BE CAREFUL WHAT YOU PUBLISH AND CONSUME!
        param($______parameters)

        try {
            if ($______parameters.ContextInOuterScope) {
                $______outerSplat = $______parameters.Context
                &$______parameters.WriteDebug "Setting context variables"
                foreach ($______current in $______outerSplat.GetEnumerator()) {
                    &$______parameters.WriteDebug "Setting context variable '$($______current.Key)' with value '$($______current.Value)'"
                    New-Variable -Name $______current.Key -Value $______current.Value -Force #-Scope Local
                }
                $______current = $null
            }
            else {
                $______outerSplat = @{}
            }

            if ($null -ne $______parameters.OuterSetup -and $______parameters.OuterSetup.Length -gt 0) {
                &$______parameters.WriteDebug "Running outer setups"
                foreach ($______current in $______parameters.OuterSetup) {
                    &$______parameters.WriteDebug "Running outer setup { $______current }"
                    $______parameters.CurrentlyExecutingScriptBlock = $______current
                    . $______current @______outerSplat
                }
                $______current = $null
                $______parameters.OuterSetup = $null
                &$______parameters.WriteDebug "Done running outer setups"
            }
            else {
                &$______parameters.WriteDebug "There are no outer setups"
            }

            & {
                try {
                    # this is needed for nonewscope so we can do two different
                    # teardowns while running this code in the middle again (which rewrites the teardown
                    # value in the object), this way we save the first teardown and ressurect it right before
                    # needing it
                    if (-not (Test-Path 'Variable:$_________teardown2')) {
                        $_________teardown2 = $______parameters.Teardown
                    }

                    if (-not $______parameters.ContextInOuterScope) {
                        $______innerSplat = $______parameters.Context
                        &$______parameters.WriteDebug "Setting context variables"
                        foreach ($______current in $______innerSplat.GetEnumerator()) {
                            &$______parameters.WriteDebug "Setting context variable '$($______current.Key)' with value '$($______current.Value)'"
                            New-Variable -Name $______current.Key -Value $______current.Value -Force #-Scope Local
                        }
                        $______current = $null
                    }
                    else {
                        $______innerSplat = $______outerSplat
                    }

                    if ($null -ne $______parameters.Setup -and $______parameters.Setup.Length -gt 0) {
                        &$______parameters.WriteDebug "Running inner setups"
                        foreach ($______current in $______parameters.Setup) {
                            &$______parameters.WriteDebug "Running inner setup { $______current }"
                            $______parameters.CurrentlyExecutingScriptBlock = $______current
                            . $______current @______innerSplat
                        }
                        $______current = $null
                        $______parameters.Setup = $null
                        &$______parameters.WriteDebug "Done running inner setups"
                    }
                    else {
                        &$______parameters.WriteDebug "There are no inner setups"
                    }

                    &$______parameters.WriteDebug "Running scriptblock { $______current }"
                    $______parameters.CurrentlyExecutingScriptBlock = $______current
                    . $______parameters.ScriptBlock @______innerSplat

                    &$______parameters.WriteDebug "Done running scrtptblock"
                }
                catch {
                    $______parameters.ErrorRecord += $_
                    &$______parameters.WriteDebug "Fail running setups or scriptblock"
                }
                finally {
                    # this is needed for nonewscope so we can do two different
                    # teardowns while running this code in the middle again (which rewrites the teardown
                    # value in the object)
                    if ((Test-Path 'variable:_________teardown2')) {
                        # soo we are running the one time test teadown in the same scope as
                        # each block teardown and it overwrites it
                        $______parameters.Teardown = $_________teardown2
                        Remove-Variable _________teardown2
                    }

                    if ($null -ne $______parameters.Teardown -and $______parameters.Teardown.Length -gt 0) {
                        &$______parameters.WriteDebug "Running inner teardowns"
                        foreach ($______current in $______parameters.Teardown) {
                            try {
                                &$______parameters.WriteDebug "Running inner teardown { $______current }"
                                $______parameters.CurrentlyExecutingScriptBlock = $______current
                                . $______current @______innerSplat
                                &$______parameters.WriteDebug "Done running inner teardown"
                            }
                            catch {
                                $______parameters.ErrorRecord += $_
                                &$______parameters.WriteDebug "Fail running inner teardown"
                            }
                        }
                        $______current = $null

                        # nulling this variable is important when we run without new scope
                        # then $______parameters.Teardown remains set and EachBlockTeardown
                        # runs twice
                        $______parameters.Teardown = $null
                        &$______parameters.WriteDebug "Done running inner teardowns"
                    }
                    else {
                        &$______parameters.WriteDebug "There are no inner teardowns"
                    }
                }
            }
        }
        finally {

            if ($null -ne $______parameters.OuterTeardown -and $______parameters.OuterTeardown.Length -gt 0) {
                &$______parameters.WriteDebug "Running outer teardowns"
                foreach ($______current in $______parameters.OuterTeardown) {
                    try {
                        &$______parameters.WriteDebug "Running outer teardown { $______current }"
                        $______parameters.CurrentlyExecutingScriptBlock = $______current
                        . $______current @______outerSplat
                        &$______parameters.WriteDebug "Done running outer teardown"
                    }
                    catch {
                        &$______parameters.WriteDebug "Fail running outer teardown"
                        $______parameters.ErrorRecord += $_
                    }
                }
                $______parameters.OuterTeardown = $null
                $______current = $null
                &$______parameters.WriteDebug "Done running outer teardowns"
            }
            else {
                &$______parameters.WriteDebug "There are no outer teardowns"
            }
        }
    }

    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
    $SessionState = $ScriptBlock.GetType().GetProperty("SessionState", $flags).GetValue($ScriptBlock, $null)
    $SessionStateInternal = $SessionState.GetType().GetProperty('Internal', $flags).GetValue($SessionState, $null)

    # attach the original session state to the wrapper scriptblock
    # making it invoke in the same scope as $ScriptBlock
    $wrapperScriptBlock.GetType().GetProperty('SessionStateInternal', $flags).SetValue($wrapperScriptBlock, $SessionStateInternal, $null)

    $success = $true
    $break = $true
    $err = $null
    try {
        $parameters = @{
            ScriptBlock                   = $ScriptBlock
            OuterSetup                    = $OuterSetup
            Setup                         = $Setup
            Teardown                      = $Teardown
            OuterTeardown                 = $OuterTeardown
            # SameScope = $SameScope
            CurrentlyExecutingScriptBlock = $null
            ErrorRecord                   = @()
            Context                       = $Context
            ContextInOuterScope           = -not $ReduceContextToInnerScope
            WriteDebug                    = { param($Message) Write-PesterDebugMessage -Scope "CoreRuntime" $Message }
        }

        # here we are moving into the user scope if the provided
        # scriptblock was bound to user scope, so we want to take some actions
        # typically switching between user and framework timer. There are still tiny pieces of
        # framework code running in the scriptblock but we can safely ignore those becasue they are
        # just logging, so the time difference is miniscule.
        # The code might also run just in framework scope, in that case the callback can remain empty,
        # eg when we are invoking framework setup.
        & $OnUserScopeTransition
        do {
            $standardOutput = if ($NoNewScope) {
                . $wrapperScriptBlock $parameters
            }
            else {
                & $wrapperScriptBlock $parameters
            }
            # if the code reaches here we did not break
            $break = $false
        } while ($false)
    }
    catch {
        $success = $false
        $err = $_
    }

    & $OnFrameworkScopeTransition
    $errors = @( ($parameters.ErrorRecord + $err) | selectNonNull )

    return New_PSObject -Type ScriptBlockInvocationResult @{
        Success        = 0 -eq $errors.Length
        ErrorRecord    = $errors
        StandardOutput = $standardOutput
        Break          = $break
    }
}


function Reset-TestSuiteTimer {
    if ($null -eq $state.TotalStopWatch) {
        $state.TotalStopWatch = New-Object Diagnostics.Stopwatch
    }

    if ($null -eq $state.TestStopWatch) {
        $state.TestStopWatch = New-Object Diagnostics.Stopwatch
    }

    if ($null -eq $state.BlockStopWatch) {
        $state.BlockStopWatch = New-Object Diagnostics.Stopwatch
    }

    if ($null -eq $state.FrameworkStopWatch) {
        $state.FrameworkStopWatch = New-Object Diagnostics.Stopwatch
    }

    $state.TotalStopWatch.Restart()
    $state.FrameworkStopWatch.Restart()
    $state.BlockStopWatch.Reset()
    $state.TestStopWatch.Reset()
}

function Switch-Timer {
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Framework", "Block", "Test")]
        $Scope
    )

    switch ($Scope) {
        "Framework" {
            # running in framework code adds time only to the overhead timer
            $state.TestStopWatch.Stop()
            $state.BlockStopWatch.Stop()
            $state.FrameworkStopWatch.Start()
        }
        "Block" {
            $state.TestStopWatch.Stop()
            $state.BlockStopWatch.Start()
            $state.FrameworkStopWatch.Stop()
        }
        "Test" {
            $state.TestStopWatch.Start()
            $state.BlockStopWatch.Stop()
            $state.FrameworkStopWatch.Stop()

        }
        default { throw [ArgumentException]"" }
    }
}

function Find-CurrentTest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String] $Name,
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock,
        [String] $Id
    )

    $block = Get-CurrentBlock
    # todo: optimize this if too slow
    $testCanditates = @($block.Tests | where { $_.ScriptBlock.StartPosition.StartLine -eq $ScriptBlock.StartPosition.StartLine -and $_.Id -eq $Id })
    if ($testCanditates.Length -eq 1) {
        $testCanditates[0]
    }
    elseif ($testCanditates.Length -gt 1) {
        throw "Found more than one test that starts on line $($ScriptBlock.StartPosition.StartLine) and has Id '$Id' (name: $Name). How is that possible are you putting all your code in one line?"
    }
    else {
        throw "Did not find the test '$($Name)' with Id '$Id' that starts on line $($ScriptBlock.StartPosition.StartLine), how is this possible?"
    }
}

function Test-ShouldRun {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Test,
        $Filter
    )
    $fullTestPath = $Test.Path -join "."
    if ($null -eq $Filter) {
        Write-PesterDebugMessage -Scope Runtime "($fullTestPath) Test is included, because there is no filter."
        return $true
    }

    # test is excluded when any of the exclude tags match
    $tagFilter = $Filter.ExcludeTag
    if (any $tagFilter) {
        foreach ($f in $tagFilter) {
            foreach ($t in $Test.Tag) {
                if ($t -like $f) {
                    Write-PesterDebugMessage -Scope Runtime "($fullTestPath) Test is excluded, because it's tag '$t' matches exclude tag filter '$f'."
                    return $false
                }
            }
        }
    }


    $hasTagFilter = $false
    $hasMatchingTag = $false
    # test is included when it has tags and the any of the tags match
    $tagFilter = tryGetProperty $Filter Tag
    if (any $tagFilter) {
        $hasTagFilter = $true
        if (none $test.Tag) {
            Write-PesterDebugMessage -Scope Runtime "($fullTestPath) Test is excluded, beause there is a tag filter $($tagFilter -join ", ") and the test has no tags."
        }
        else {
            foreach ($f in $tagFilter) {
                foreach ($t in $Test.Tag) {
                    if ($t -like $f) {
                        Write-PesterDebugMessage -Scope Runtime "($fullTestPath) Test is included, because it's tag '$t' matches tag filter '$f'."
                        $hasMatchingTag = $true
                        break
                    }
                }
            }
        }
    }

    $hasMatchingPath = $false
    $hasPathFilter = $false
    $allPaths = tryGetProperty $Filter Path | % { $_ -join '.' }
    if (any $allPaths) {
        $hasPathFilter = $true
        $include = $allPaths -contains $fullTestPath
        if ($include) {
            Write-PesterDebugMessage -Scope Runtime "($fullTestPath) Test is included, because it matches full path filter."
            $hasMatchingPath = $true
        }
        else {
            Write-PesterDebugMessage -Scope Runtime "($fullTestPath) Test is excluded, because its full path does not match the path filter."
        }
    }


    (-not $hasTagFilter -and -not $hasPathFilter) -or ($hasTagFilter -and $hasMatchingTag) -or ($hasPathFilter -and $hasMatchingPath)
}

function Invoke-Test {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSTypeName("BlockContainer")][PSObject[]] $BlockContainer,
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState,
        $Filter,
        $Plugin
    )

    $state.Plugin = $Plugin

    # # TODO: this it potentially unreliable, because supressed errors are written to Error as well. And the errors are captured only from the caller state. So let's use it only as a useful indicator during migration and see how it works in production code.

    # # finding if there were any non-terminating errors during the run, user can clear the array, and the array has fixed size so we can't just try to detect if there is any difference by counts before and after. So I capture the last known error in that state and try to find it in the array after the run
    # $originalErrors = $SessionState.PSVariable.Get("Error").Value
    # $originalLastError = $originalErrors[0]
    # $originalErrorCount = $originalErrors.Count

    $found = Discover-Test -BlockContainer $BlockContainer -Filter $Filter -SessionState $SessionState

    # $errs = $SessionState.PSVariable.Get("Error").Value
    # $errsCount = $errs.Count
    # if ($errsCount -lt $originalErrorCount) {
    #     # it would be possible to detect that there are 0 errors, in the array and continue,
    #     # but this still indicates the user code is running where it should not, so let's throw anyway
    #     throw "Test discovery failed. The error count ($errsCount) after running discovery is lower than the error count before discovery ($originalErrorCount). Is some of your code running outside Pester controlled blocks and it clears the `$error array by calling `$error.Clear()?"

    # }


    if ($originalErrorCount -lt $errsCount) {
        # probably the most usual case,  there are more errors then there were before,
        # so some were written to the screen, this also runs when the user cleared the
        # array and wrote more errors than there originally were
        $i = $errsCount - $originalErrorCount
    }
    else {
        # there is equal amount of errors, the array was probabably full and so the original
        # error shifted towards the end of the array, we try to find it and see how many new
        # errors are there
        for ($i = 0 ; $i -lt $errsLength; $i++) {
            if ([object]::referenceEquals($errs[$i], $lastError)) {
                break
            }
        }
    }
    if (0 -ne $i) {
        throw "Test discovery failed. There were $i non-terminating errors during test discovery. This indicates that some of your code is invoked outside of Pester controlled blocks and fails. No tests will be run."
    }
    Run-Test -Block $found -SessionState $SessionState
}

function PostProcess-DiscoveredBlock {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSTypeName("DiscoveredBlock")][PSObject] $Block,
        [PSTypeName("Filter")] $Filter,
        [PSTypeName("BlockContainer")] $BlockContainer,
        [PSTypeName("DiscoveredBlock")][PSObject] $RootBlock
    )

    # traverses the block structure after a block was found and
    # link childs to their parents, filter blocks and tests to
    # determine which should run, and mark blocks and tests
    # as first or last to know when one time setups & teardowns should run
    if ($Block -eq $RootBlock) {
        $Block.IsRoot = $true
    }
    $Block.Root = $RootBlock
    $Block.BlockContainer = $BlockContainer

    $tests = $Block.Tests
    $blockShouldRun = $false
    if (any $tests) {
        foreach ($t in $tests) {
            $t.ShouldRun = Test-ShouldRun -Test $t -Filter $Filter
        }

        $testsToRun = $tests | where { $_.ShouldRun }
        if (any $testsToRun) {
            $testsToRun[0].First = $true
            $testsToRun[-1].Last = $true
            $blockShouldRun = $true
        }
    }

    $childBlocks = $Block.Blocks
    $anyChildBlockShouldRun = $false
    if (any $childBlocks) {
        foreach ($cb in $childBlocks) {
            $cb.Parent = $Block
            PostProcess-DiscoveredBlock -Block $cb -Filter $Filter -BlockContainer $BlockContainer -RootBlock $RootBlock
        }

        $childBlocksToRun = $childBlocks | where { $_.ShouldRun }
        $anyChildBlockShouldRun = any $childBlocksToRun
        if ($anyChildBlockShouldRun) {
            $childBlocksToRun[0].First = $true
            $childBlocksToRun[-1].Last = $true
        }
    }

    $Block.ShouldRun = $blockShouldRun -or $anyChildBlockShouldRun
}


function PostProcess-ExecutedBlock {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSTypeName("DiscoveredBlock")][PSObject[]] $Block
    )


    # traverses the block structure after a block was executed and
    # and sets the failures correctly so the aggreagatted failures
    # propagate towards the root so if a child test fails it's block
    # aggregated result should be marked as failed

    process {
        foreach ($b in $Block) {
            $thisBlockFailed = -not $b.Passed
            $tests = $b.Tests
            $anyTestFailed = any ($tests | where { $_.Executed -and -not $_.Passed })
            $testDuration = sum $tests 'Duration' ([TimeSpan]::Zero)

            $childBlocks = $b.Blocks
            $anyChildBlockFailed = $false
            $aggregatedChildDuration = [TimeSpan]::Zero
            if (any $childBlocks) {
                foreach ($cb in $childBlocks) {
                    PostProcess-ExecutedBlock -Block $cb
                }
                $aggregatedChildDuration = sum $childBlocks 'AggregatedDuration' ([TimeSpan]::Zero)
                $anyChildBlockFailed = any ($childBlocks | where { $_.Executed -and -not $_.Passed })
            }


            $b.AggregatedPassed = -not ($thisBlockFailed -or $anyTestFailed -or $anyChildBlockFailed)
            $b.AggregatedDuration = $b.Duration + $testDuration + $aggregatedChildDuration
        }
    }
}

function Where-Failed {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Block
    )

    $Block | View-Flat | Where { -not $_.Passed }
}

function View-Flat {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Block
    )

    # invert to make tests all at the same level
    $blocks = flattenBlock -Block $Block -Accumulator @()
    foreach ($block in $blocks) {
        foreach ($test in $block.Tests) {
            $test | select *, @{n = "Block"; e = {$block}}
        }
    }
}

function flattenBlock ($Block, $Accumulator) {
    $Accumulator += $Block
    if ($Block.Blocks.Length -eq 0) {
        return $Accumulator
    }

    foreach ($bl in $Block.Blocks) {
        flattenBlock -Block $bl -Accumulator $Accumulator
    }
    $Accumulator
}

function Find-CurrentBlock {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String] $Name,
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )

    $blocks = (Get-CurrentBlock).Blocks
    # todo: optimize this if too slow
    $blockCandidates = @($blocks | where { $_.Name -eq $Name })
    if ($blockCandidates.Length -eq 1) {
        $blockCandidates[0]
    }
    elseif ($blockCandidates.Length -gt 1) {
        $found = @($blockCandidates | where { $ScriptBlock.StartPosition.StartLine -eq $_.ScriptBlock.StartPosition.StartLine })

        if ($found.Length -eq 1) {
            $found
        }
        elseif ($found.Length -eq 0) {
            throw "Could not find block '$Name' that starts on line $($ScriptBlock.StartPosition.StartLine)"
        }
        else {
            throw "Found multiple blocks that start on the same line $($ScriptBlock.StartPosition.StartLine) how is that possible?"
        }
    }
    else {
        throw "Did not find the block '$($Name)', how is this possible?"
    }
}

function New-FilterObject {
    [CmdletBinding()]
    param (
        [String[][]] $Path,
        [String[]] $Tag,
        [String[]] $ExcludeTag
    )

    New_PSObject -Type "Filter" -Property @{
        Path       = $Path
        Tag        = $Tag
        ExcludeTag = $ExcludeTag
    }
}

function New-PluginObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String] $Name,
        [ScriptBlock] $OneTimeBlockSetup,
        [ScriptBlock] $EachBlockSetup,
        [ScriptBlock] $OneTimeTestSetup,
        [ScriptBlock] $EachTestSetup,
        [ScriptBlock] $EachTestTeardown,
        [ScriptBlock] $OneTimeTestTeardown,
        [ScriptBlock] $EachBlockTeardown,
        [ScriptBlock] $OneTimeBlockTeardown
    )

    New_PSObject -Type "Plugin" @{
        OneTimeBlockSetup    = $OneTimeBlockSetup
        EachBlockSetup       = $EachBlockSetup
        OneTimeTestSetup     = $OneTimeTestSetup
        EachTestSetup        = $EachTestSetup
        EachTestTeardown     = $EachTestTeardown
        OneTimeTestTeardown  = $OneTimeTestTeardown
        EachBlockTeardown    = $EachBlockTeardown
        OneTimeBlockTeardown = $OneTimeBlockTeardown
    }
}

function Invoke-BlockContainer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        # relaxing the type here, I need it to have two forms and
        # PowerShell cannot do that probably
        # [PSTypeName("BlockContainer"] | [PSTypeName("DiscoveredBlockContainer")]
        $BlockContainer,
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState
    )

    switch ($BlockContainer.Type) {
        "ScriptBlock" { & $BlockContainer.Content }
        "File" { Invoke-File -Path $BlockContainer.Content.PSPath -SessionState $SessionState }
        default { throw [System.ArgumentOutOfRangeException]"" }
    }
}

function New-BlockContainerObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ParameterSetName = "ScriptBlock")]
        [ScriptBlock] $ScriptBlock,
        [Parameter(Mandatory, ParameterSetName = "Path")]
        [String] $Path,
        [Parameter(Mandatory, ParameterSetName = "File")]
        [System.IO.FileInfo] $File
    )

    $type, $content = switch ($PSCmdlet.ParameterSetName) {
        "ScriptBlock" { "ScriptBlock", $ScriptBlock }
        "Path" { "File", (Get-Item $Path) }
        "File" { "File", $File }
        default { throw [System.ArgumentOutOfRangeException]"" }
    }

    New_PSObject -Type "BlockContainer" @{
        Type    = $type
        Content = $content
    }
}

function New-DiscoveredBlockContainerObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSTypeName('BlockContainer')] $BlockContainer,
        [Parameter(Mandatory)]
        [PSTypeName('DiscoveredBlock')][PSObject[]] $Block
    )

    New_PSObject -Type "DiscoveredBlockContainer" @{
        Type    = $BlockContainer.Type
        Content = $BlockContainer.Content
        # I create a Root block to keep the discovery unaware of containers,
        # but I don't want to publish that root block because it contains properties
        # that do not make sense on container level like Name and Parent,
        # so here we don't want to take the root block but the blocks inside of it
        # and copy the rest of the meaningful properties
        Blocks  = $Block.Blocks
    }
}

function Invoke-File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]
        $Path,
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState
    )

    $sb = {
        param ($p)
        . $($p; Remove-Variable -Scope Local -Name p)
    }

    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
    $SessionStateInternal = $SessionState.GetType().GetProperty('Internal', $flags).GetValue($SessionState, $null)

    # attach the original session state to the wrapper scriptblock
    # making it invoke in the caller session state
    $sb.GetType().GetProperty('SessionStateInternal', $flags).SetValue($sb, $SessionStateInternal, $null)

    # dot source the caller bound scriptblock which imports it into user scope
    & $sb $Path
}

function Import-Dependency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Dependency,
        # [Parameter(Mandatory=$true)]
        [Management.Automation.SessionState] $SessionState
    )

    if ($Dependency -is [ScriptBlock]) {
        . $Dependency
    }
    else {

        # when importing a file we need to
        # dot source it into the user scope, the path has
        # no bound session state, so simply dot sourcing it would
        # import it into module scope
        # instead we wrap it into a scriptblock that we attach to user
        # scope, and dot source the file, that will import the functions into
        # that script block, and then we dot source it again to import it
        # into the caller scope, effectively defining the functions there
        $sb = {
            param ($p)

            . $($p; Remove-Variable -Scope Local -Name p)
        }

        $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
        $SessionStateInternal = $SessionState.GetType().GetProperty('Internal', $flags).GetValue($SessionState, $null)

        # attach the original session state to the wrapper scriptblock
        # making it invoke in the caller session state
        $sb.GetType().GetProperty('SessionStateInternal', $flags).SetValue($sb, $SessionStateInternal, $null)

        # dot source the caller bound scriptblock which imports it into user scope
        . $sb $Dependency
    }
}

function Add-FrameworkDependency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Dependency
    )

    # adds dependency that is dotsourced during discovery & execution
    # this should be rarely needed, but is useful when you wrap Pester pieces
    # into your own functions, and want to have them available during both
    # discovery and execution
    Write-Host "Adding framework dependency '$Dependency'" -ForegroundColor Yellow
    Import-Dependency -Dependency $Dependency -SessionState $SessionState
}

function Add-Dependency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Dependency,
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState
    )


    # adds dependency that is dotsourced after discovery and before execution
    if (-not (Is-Discovery)) {
        Write-Host "Adding run-time dependency '$Dependency'" -ForegroundColor Yellow
        Import-Dependency -Dependency $Dependency -SessionState $SessionState
    }
}

function Add-FreeFloatingCode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock
    )

    # runs piece of code during execution, useful for backwards compatibility
    # when you have stuff laying around inbetween describes and want to run it
    # only during execution and not twice. works the same as Add-Dependency, but I name
    # it differently because this is a bad-practice mitigation tool and should probably
    # write a warning to make you use Before* blocks instead
    if (-not (Is-Discovery)) {
        Write-Host Invoking free floating piece of code -ForegroundColor Yellow
        Import-Dependency $Dependency
    }
}

function New-ParametrizedTest () {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String] $Name,
        [Parameter(Mandatory = $true, Position = 1)]
        [ScriptBlock] $ScriptBlock,
        [String[]] $Tag = @(),
        [HashTable[]] $Data = @{},
        [Switch] $Focus
    )

    Switch-Timer -Scope Framework
    $counter = 0
    foreach ($d in $Data) {
        New-Test -Id ($counter++) -Name $Name -Tag $Tag -ScriptBlock $ScriptBlock -Data $d -Focus:$Focus
    }
}

function Recurse-Up {
    param(
        [Parameter(Mandatory)]
        $InputObject,
        [ScriptBlock] $Action
    )

    $i = $InputObject
    $level = 0
    while ($null -ne $i) {
        &$Action $i

        $level--
        $i = $i.Parent
    }
}


Import-Module $PSScriptRoot\stack.psm1 -DisableNameChecking
# initialize internal state
Reset-TestSuiteState

Export-ModuleMember -Function @(
    # the core stuff I am mostly sure about
    'Reset-TestSuiteState'
    'New-Block'
    'New-Test'
    'New-ParametrizedTest'
    'New-EachTestSetup'
    'New-EachTestTeardown'
    'New-OneTimeTestSetup'
    'New-OneTimeTestTeardown'
    'New-EachBlockSetup'
    'New-EachBlockTeardown'
    'New-OneTimeBlockSetup'
    'New-OneTimeBlockTeardown'
    'Add-Dependency'
    'Add-FrameworkDependency'
    'Add-FreeFloatingCode'
    'Invoke-Test',
    'Find-Test',

    # here I have doubts if that is too much to expose
    'Get-CurrentTest'
    'Get-CurrentBlock'
    'Recurse-Up',
    'Is-Discovery'

    # those are quickly implemented to be useful for demo
    'Where-Failed'
    'View-Flat'

    # those need to be refined and probably wrapped to something
    # that is like an object builder
    'New-FilterObject'
    'New-PluginObject'
    'New-BlockContainerObject'
)
