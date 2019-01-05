$state = [PSCustomObject]@{
    Root = $null
    CurrentBlock = $null
    Discovery = $false
    Filter = $null
    Plugin = $null
}

Write-Host -ForegroundColor Cyan "----> Importing pester runtime"
# resets the module state to the default
function Reset-TestSuite {
    v "Resetting internal state to default."
    $state.Root = $null
    $state.Discovery = $false
    $state.CurrentBlock = $state.Root = New-BlockObject -Name "Block"
    $state.Filter = $null
    $state.Plugin = $null
    Reset-Scope
}

# compatibility
function Test-NullOrWhiteSpace ($Value) {
    # psv2 compatibility, on newer .net we would simply use
    # [string]::isnullorwhitespace
    $null -eq $Value -or $Value -match "^\s*$"
}

function New-PSObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [HashTable] $Property,
        [String] $Type
    )

    if (-not (Test-NullOrWhiteSpace $Type) -and -not $Property.ContainsKey($Type))
    {
        $Property.Add("PSTypeName", $Type)
    }

    New-Object -Type PSObject -Property $Property
}

###

function v {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String] $Message
    )

    # Write-Host -ForegroundColor Blue $Message
}

function Find-Test {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [PsTypeName("TestContainer")] $Test
    )
    v "Starting test discovery."
    $state.Discovery = $true

    $null = Invoke-TestContainer -Test $Test

    $Test.Blocks = $state.Root
    v "Test discovery finished."
}


# endpoint for adding a block that contains tests
# or other blocks
function New-Block {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String] $Name,
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock
    )

    Push-Scope -Scope (New-Scope -Name $Name -Hint Block)
    $path = Get-ScopeHistory | % Name
    v "Entering path $($path -join '.')"

    $block = $null

    if (Is-Discovery) {
        v "Adding block $Name to discovered blocks"
        $block = New-BlockObject -Name $Name -Path $path
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
            v "Discovering in body of block $Name"
            & $ScriptBlock
            v "Finished discovering in body of block $Name"
        }
        else {
            if (-not $block.ShouldRun) {
                v "Block is excluded from run, returning"
                return
            }
            v "Executing body of block $Name"


            $result = Invoke-ScriptBlock `
                -ScriptBlock $ScriptBlock `
                -OuterSetup ( combineNonNull @(
                        $state.Plugin | tryGetProperty OneTimeBlockSetup
                        $previousBlock.OneTimeBlockSetup
                ) ) `
                -Setup ( combineNonNull @(
                    $state.Plugin | tryGetProperty EachBlockSetup
                    $previousBlock.EachBlockSetup
                ) ) `
                -Teardown ( combineNonNull @(
                    $previousBlock.EachBlockTeardown
                    $state.Plugin | tryGetProperty EachBlockTeardown
                ) ) `
                -OuterTeardown (
                    combineNonNull @(
                        $previousBlock.OneTimeBlockTeardown
                        $state.Plugin | tryGetProperty OneTimeBlockTeardown
                ) ) `
                -Context @{
                    Context = $block | Select -Property Name
                }

            $block.Executed = $true
            $block.Passed = $result.Success
            $block.StandardOutput = $result.StandardOutput

            $block.ErrorRecord = $result.ErrorRecord
            v "Finished executing body of block $Name"
        }
    }
    finally {
        v "Leaving path $($path -join '.')"
        Set-CurrentBlock -Block $previousBlock
        $null = Pop-Scope
        v "Left block $Name"
    }
}

# endpoint for adding a test
function New-Test {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String] $Name,
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock,
        [String[]] $Tag = @()
    )

    v "Entering test $Name"
    Push-Scope -Scope (New-Scope -Name $Name -Hint Test)
    try {
        $path = Get-ScopeHistory | % Name
        v "Entering path $($path -join '.')"

        # do this setup when we are running discovery
        if (Is-Discovery) {
            Add-Test -Test (New-TestObject -Name $Name -Path $path -Tag $Tag)
            v "Added test '$Name'"
        }
        else {
            $test = Find-CurrentTest -Name $Name -ScriptBlock $ScriptBlock
            if (-not $test.ShouldRun) {
                v "Test is excluded from run, returning"
                return
            }

            $block = Get-CurrentBlock

            v "Running test '$Name'."
            $frameworkSetupResult = Invoke-ScriptBlock `
                -OuterSetup @(
                    if ($test.First) { $state.Plugin.OneTimeTestSetup | hasValue }
                ) `
                -Setup @( $state.Plugin.EachTestSetup | hasValue ) `
                -ScriptBlock {} `
                -Context @{
                    Context = $Test | Select -Property Name, Path
                }

            if ($frameworkSetupResult.Success) {
                # invokes the body of the test
                $result = Invoke-ScriptBlock `
                    -OuterSetup @(
                        if ($test.First) { $block.OneTimeTestSetup | hasValue }
                    ) `
                    -Setup @( $block.EachTestSetup | hasValue ) `
                    -ScriptBlock $ScriptBlock `
                    -Teardown @( $block.EachTestTeardown | hasValue ) `
                    -OuterTeardown @(
                        if ($test.Last) { $block.OneTimeTestTeardown | hasValue }
                    ) `
                    -Context @{
                        Context = $Test | Select -Property Name, Path
                    }

                $test.Executed = $true
                $test.Passed = $result.Success
                $test.StandardOutput = $result.StandardOutput
                $test.ErrorRecord = $result.ErrorRecord
            }

            $frameworkTeardownResult = Invoke-ScriptBlock `
                -ScriptBlock {} `
                -Teardown @( $state.Plugin.EachTestTeardown | hasValue ) `
                -OuterTeardown @(
                    if ($test.Last) { $state.Plugin.OneTimeTestTeardown | hasValue }
                ) `
                -Context @{
                    Context = $Test | Select -Property Name, Path, Passed, ErrorRecord
                }

            if (-not $frameworkTeardownResult.Success -or -not $frameworkTeardownResult.Success) {
                throw "framework error"
            }
        }
    }
    finally {

        v "Leaving path $($path -join '.')"
        $null = Pop-Scope
        v "Left test $Name"
    }

}

# endpoint for adding a setup for each test in the block
function New-EachTestSetup {
    param (
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock
    )

    (Get-CurrentBlock).EachTestSetup = $ScriptBlock
}

# endpoint for adding a teardown for each test in the block
function New-EachTestTeardown {
    param (
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock
    )

    (Get-CurrentBlock).EachTestTeardown = $ScriptBlock
}

# endpoint for adding a setup for all tests in the block
function New-OneTimeTestSetup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock
    )

    (Get-CurrentBlock).OneTimeTestSetup = $ScriptBlock
}

# endpoint for adding a teardown for all tests in the block
function New-OneTimeTestTeardown {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock
    )

    (Get-CurrentBlock).OneTimeTestTeardown = $ScriptBlock
}

# endpoint for adding a setup for each block in the current block
function New-EachBlockSetup {
    param (
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock
    )

    (Get-CurrentBlock).EachBlockSetup = $ScriptBlock
}

# endpoint for adding a teardown for each block in the current block
function New-EachBlockTeardown {
    param (
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock
    )

    (Get-CurrentBlock).EachBlockTeardown = $ScriptBlock
}

# endpoint for adding a setup for all blocks in the current block
function New-OneTimeBlockSetup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock
    )

    (Get-CurrentBlock).OneTimeBlockSetup = $ScriptBlock
}

# endpoint for adding a teardown for all clocks in the current block
function New-OneTimeBlockTeardown {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock
    )

    (Get-CurrentBlock).OneTimeBlockTeardown = $ScriptBlock
}

function Get-CurrentBlock {
    [CmdletBinding()]
    param ( )
    $state.CurrentBlock
}

function Set-CurrentBlock {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Block
    )

    $state.CurrentBlock = $Block
}

function Add-Test {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [PSTypeName("DiscoveredTest")]
        $Test
    )

    (Get-CurrentBlock).Tests += $Test
}

function New-TestObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String] $Name,
        [String[]] $Path,
        [String[]] $Tag
    )

    New-PSObject -Type DiscoveredTest @{
        Name = $Name
        Path = $Path
        Tag = $Tag
        Executed = $false
        Passed = $false
        StandardOutput = $null
        ErrorRecord = @()
        First = $false
        Last = $false
        ShouldRun = $false
    }
}

function New-BlockObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String] $Name,
        [string[]] $Path
    )

    New-PSObject -Type DiscoveredBlock @{
        Name = $Name
        Path = @()
        Tests = @()
        EachTestSetup = $null
        OneTimeTestSetup = $null
        EachTestTeardown = $null
        OneTimeTestTeardown = $null
        EachBlockSetup = $null
        OneTimeBlockSetup = $null
        EachBlockTeardown = $null
        OneTimeBlockTeardown = $null
        Blocks = @()
        Executed = $false
        Passed = $false
        First = $false
        Last = $false
        StandardOutput = $null
        ErrorRecord = @()
        ShouldRun = $false
    }
}

function Add-Block {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [PSTypeName("DiscoveredBlock")]
        $Block
    )

    (Get-CurrentBlock).Blocks += $block
}

function Is-Discovery {
    $state.Discovery
}

# test invocation
function Start-Test {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [PSTypeName("TestContainer")] $Test
    )

    $state.Discovery = $false
    # do we want this output?
    $null = Invoke-TestContainer $Test
    $state.Root
}

function Invoke-ScriptBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock,
        [ScriptBlock[]] $OuterSetup,
        [ScriptBlock[]] $Setup,
        [ScriptBlock[]] $Teardown,
        [ScriptBlock[]] $OuterTeardown,
        $Context = @{},
        # # setup, body and teardown will all run (be-dotsourced into)
        # # the same scope
        # [Switch] $SameScope,
        # will dot-source the wrapper scriptblock instead of invoking it
        # so in combination with the SameScope switch we are effectively
        # running the code in the current scope
        [Switch] $NoNewScope
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

    $scriptBlockWithContext = {
        # THIS RUNS IN USER SCOPE, BE CAREFUL WHAT YOU PUBLISH AND CONSUME!
        param($______context)
        $______splat = $______context.Parameters
        try {
            if ($null -ne $______context.OuterSetup -and $______context.OuterSetup.Length -gt 0) {
                &$______context.WriteDebug "Running outer setups"
                foreach ($______current in $______context.OuterSetup) {
                    &$______context.WriteDebug "Running outer setup { $______current }"
                    $______context.CurrentlyExecutingScriptBlock = $______current
                    . $______current @______splat
                }
                &$______context.WriteDebug "Done running outer setups"
            }
            else {
                &$______context.WriteDebug "There are no outer setups"
            }

            & {
                try {

                    if ($null -ne $______context.Setup -and $______context.Setup.Length -gt 0) {
                        &$______context.WriteDebug "Running inner setups"
                        foreach ($______current in $______context.Setup) {
                            &$______context.WriteDebug "Running inner setup { $______current }"
                            $______context.CurrentlyExecutingScriptBlock = $______current
                            . $______current @______splat
                        }
                        &$______context.WriteDebug "Done running inner setups"
                    }
                    else {
                        &$______context.WriteDebug "There are no inner setups"
                    }

                    &$______context.WriteDebug "Running scriptblock"
                    . $______context.ScriptBlock @______splat
                    &$______context.WriteDebug "Done running scriptblock"
                }
                catch {
                    $______context.ErrorRecord += $_
                    &$______context.WriteDebug "Fail running setups or scriptblock"
                }
                finally {
                    if ($null -ne $______context.Teardown -and $______context.Teardown.Length -gt 0) {
                        &$______context.WriteDebug "Running inner teardowns"
                        foreach ($______current in $______context.Teardown) {
                            try {
                                &$______context.WriteDebug "Running inner teardown { $______current }"
                                $______context.CurrentlyExecutingScriptBlock = $______current
                                . $______current @______splat
                                &$______context.WriteDebug "Done running inner teardown"
                            }
                            catch {
                                $______context.ErrorRecord += $_
                                &$______context.WriteDebug "Fail running inner teardown"
                            }
                        }
                        &$______context.WriteDebug "Done running inner teardowns"
                    }
                    else {
                        &$______context.WriteDebug "There are no inner teardowns"
                    }
                }
            }
        }
        finally {

            if ($null -ne $______context.OuterTeardown -and $______context.OuterTeardown.Length -gt 0) {
                &$______context.WriteDebug "Running outer teardowns"
                foreach ($______current in $______context.OuterTeardown) {
                    try {
                        &$______context.WriteDebug "Running outer teardown { $______current }"
                        $______context.CurrentlyExecutingScriptBlock = $______current
                        . $______current @______splat
                        &$______context.WriteDebug "Done running outer teardown"
                    }
                    catch {
                        &$______context.WriteDebug "Fail running outer teardown"
                        $______context.ErrorRecord += $_
                    }
                }
                &$______context.WriteDebug "Done running outer teardowns"
            }
            else {
                &$______context.WriteDebug "There are no outer teardowns"
            }
        }
    }

    $flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
    $SessionState = $ScriptBlock.GetType().GetProperty("SessionState", $flags).GetValue($ScriptBlock, $null)
    $SessionStateInternal = $SessionState.GetType().GetProperty('Internal', $flags).GetValue($SessionState, $null)

    # attach the original session state to the wrapper scriptblock
    # making it invoke in the same scope as $ScriptBlock
    $scriptBlockWithContext.GetType().GetProperty('SessionStateInternal', $flags).SetValue($scriptBlockWithContext, $SessionStateInternal, $null)

    $success = $true
    $break = $true
    try {
        do {
            $context =  @{
                ScriptBlock = $ScriptBlock
                OuterSetup = $OuterSetup
                Setup = $Setup
                Teardown = $Teardown
                OuterTeardown = $OuterTeardown
                SameScope = $SameScope
                CurrentlyExecutingScriptBlock = $null
                ErrorRecord = @()
                Parameters = $Context
                WriteDebug = {} # { param( $Message )  Write-Host -ForegroundColor Magenta $Message }
            }
            $standardOutput = if ($NoNewScope) {
                    . $scriptBlockWithContext $context
                }
                else {
                    & $scriptBlockWithContext $context
                }
            # if the code reaches here we did not break
            $break = $false
        } while ($false)
    }
    catch {
        $success = $false
        $err = $_
    }
    $errors = @( ($context.ErrorRecord + $err) | hasValue )

    return New-PSObject -Type ScriptBlockInvocationResult @{
        Success = 0 -eq $errors.Length
        ErrorRecord = $errors
        StandardOutput = $standardOutput
        Break = $break
    }
}

function Find-CurrentTest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String] $Name,
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock
    )

    $block = Get-CurrentBlock
    # todo: optimize this if too slow
    $testCanditates = @($block.Tests | where { $_.Name -eq $Name })
    if ($testCanditates.Length -eq 1) {
        $testCanditates[0]
    }
    elseif ($testCanditates.Length -gt 1) {
        #todo find it by script block
    }
    else {
        throw "Did not find the test '$($Name)', how is this possible?"
    }
}

function Set-Filter {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Filter
    )

    $state.Filter = $Filter
}

function Test-ShouldRun {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Test,
        $Filter
    )
    $fullTestPath = $Test.Path -join "."
    if ($null -eq $Filter) {
        v "($fullTestPath) Test is included, because there is no filter."
        return $true
    }

    # test is excluded when any of the exclude tags match
    $tagFilter = $Filter.ExcludeTag
    if (any $tagFilter) {
        foreach ($f in $tagFilter) {
            foreach ($t in $Test.Tag) {
                if ($t -like $f) {
                    v "($fullTestPath) Test is excluded, because it's tag '$t' matches exclude tag filter '$f'."
                    return $false
                }
            }
        }
    }


    $hasTagFilter = $false
    $hasMatchingTag = $false
    # test is included when it has tags and the any of the tags match
    $tagFilter = $Filter | tryGetProperty Tag
    if (any $tagFilter) {
        $hasTagFilter = $true
        if (none $test.Tag) {
            v "($fullTestPath) Test is excluded, beause there is a tag filter $($tagFilter -join ", ") and the test has no tags."
        }
        else {
            foreach ($f in $tagFilter) {
                foreach ($t in $Test.Tag) {
                    if ($t -like $f) {
                        v "($fullTestPath) Test is included, because it's tag '$t' matches tag filter '$f'."
                        $hasMatchingTag = $true
                        break
                    }
                }
            }
        }
    }

    $hasMatchingPath = $false
    $hasPathFilter = $false
    $allPaths = $Filter | tryGetProperty Path | % { $_ -join '.' }
    if (any $allPaths) {
        $hasPathFilter = $true
        $include = $allPaths -contains $fullTestPath
        if ($include) {
            v "($fullTestPath) Test is included, because it matches full path filter."
            $hasMatchingPath = $true
        }
        else {
            v "($fullTestPath) Test is excluded, because is full path does not match the path filter."
        }
    }


    (-not $hasTagFilter -and -not $hasPathFilter) -or ($hasTagFilter -and $hasMatchingTag) -or ($hasPathFilter -and $hasMatchingPath)
}

function Invoke-Test {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [PSTypeName("TestContainer")][PSObject[]] $Test,
        $Filter,
        $Plugin
    )

    
    foreach ($container in $Test) {
        Reset-TestSuite
        $state.Plugin = $Plugin
        if ($filter) {
            Set-Filter $filter
        }

        $found = Find-Test $container

        $state.CurrentBlock = $state.Root
        PostProcess-Test $state.Root

        $result = Start-Test $container
        $result
    }
}

function PostProcess-Test {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $Block
    )

    $tests = $Block.Tests
    $blockShouldRun = $false
    if (any $tests) {
        foreach ($t in $tests) {
            $t.ShouldRun = Test-ShouldRun -Test $t -Filter $state.Filter
        }

        $testsToRun = $tests | where { $_.ShouldRun }
        $testsToRun | select -First 1 | trySetProperty First $true
        $testsToRun | select -Last 1 | trySetProperty Last $true
        $blockShouldRun = any $testsToRun
    }

    $blocks = $Block.Blocks
    if (any $blocks) {
        $blocks[0].First = $true
        $blocks[-1].Last = $true
        foreach($b in $blocks) {
            PostProcess-Test -Block $b
        }
    }

    $anyChildBlockShouldRun = $blocks | where { $_.ShouldRun }
    $block.ShouldRun = $blockShouldRun -or $anyChildBlockShouldRun
}

function Where-Failed {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $Block
    )

    $Block | View-Flat | Where { -not $_.Passed }
}

function View-Flat {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $Block
    )

    # invert to make tests all at the same level
    $blocks = flattenBlock -Block $Block -Accumulator @()
    foreach ($block in $blocks) {
        foreach ($test in $block.Tests) {
            $test | select *, @{n="Block"; e={$block}}
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
        [Parameter(Mandatory=$true)]
        [String] $Name,
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock
    )


    $blocks = (Get-CurrentBlock).Blocks
    # todo: optimize this if too slow
    $blockCandidates = @($blocks | where { $_.Name -eq $Name })
    if ($blockCandidates.Length -eq 1) {
        $blockCandidates[0]
    }
    elseif ($blockCandidates.Length -gt 1) {
        #todo find it by script block
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

    New-PSObject -Type "Filter" -Property @{
        Path = $Path
        Tag = $Tag
        ExcludeTag = $ExcludeTag
    }
}

function New-PluginObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
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

    New-PSObject -Type "Plugin" @{
        OneTimeBlockSetup = $OneTimeBlockSetup
        EachBlockSetup = $EachBlockSetup
        OneTimeTestSetup = $OneTimeTestSetup
        EachTestSetup = $EachTestSetup
        EachTestTeardown = $EachTestTeardown
        OneTimeTestTeardown = $OneTimeTestTeardown
        EachBlockTeardown = $EachBlockTeardown
        OneTimeBlockTeardown = $OneTimeBlockTeardown
    }
}

function Invoke-TestContainer { 
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSTypeName("TestContainer")] $Test
    )

    switch ($Test.Type) {
        "ScriptBlock" { & $Test.Content } 
        "File" { & $Test.Content.PSPath }
        default { throw [System.ArgumentOutOfRangeException]"" }
    }
}
function New-TestContainerObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ParameterSetName = "ScriptBlock")]
        [ScriptBlock] $ScriptBlock,
        [Parameter(Mandatory, ParameterSetName = "File")]
        [String] $Path
    )


    $content = switch ($PSCmdlet.ParameterSetName) {
        "ScriptBlock" { $ScriptBlock }
        "File" { Get-Item $Path }
        default { throw [System.ArgumentOutOfRangeException]"" }
    }

    New-PSObject -Type "TestContainer" @{
        Id = (New-Guid).Guid
        Type = $PSCmdlet.ParameterSetName
        Content = $content,
        Blocks = @()
    }
}


function or {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position = 0)]
        $DefaultValue,
        [Parameter(ValueFromPipeline = $true)]
        $InputObject
    )

    if ($InputObject) {
        $InputObject
    }
    else {
        $DefaultValue
    }
}

# looks for a property on object that might be null
function tryGetProperty {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position = 0)]
        $PropertyName,
        [Parameter(ValueFromPipeline = $true)]
        $InputObject
    )
    if ($null -eq $InputObject) {
        return
    }

    $InputObject.$PropertyName

    # this would be useful if we looked for property that might not exist
    # but that is not the case so-far. Originally I implemented this incorrectly
    # so I will keep this here for reference in case I was wrong the second time as well
    # $property = $InputObject.PSObject.Properties.Item($PropertyName)
    # if ($null -ne $property) {
    #     $property.Value
    # }
}

function trySetProperty {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position = 0)]
        $PropertyName,
        [Parameter(Mandatory=$true, Position = 1)]
        $Value,
        [Parameter(ValueFromPipeline = $true)]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return
    }

    $InputObject.$PropertyName = $Value
}


# combines collections that are not null or empty, but does not remove null values
# from collections so e.g. combineNonNull @(@(1,$null), @(1,2,3), $null, $null, 10)
# returns 1, $null, 1, 2, 3, 10
function combineNonNull ($Array) {
    foreach ($i in $Array) {

        $arr = @($i)
        if ($null -ne $i -and $arr.Length -gt 0) {
            foreach ($a in $arr) {
                $a
            }
        }
    }
}

filter hasValue {
    $_ | where { $_ }
}

function any ($InputObject) {
    if ($null -eq $InputObject) {
        return $false
    }

    0 -lt $InputObject.Length
}

function none ($InputObject) {
    -not (any $InputObject)
}

Import-Module $PSScriptRoot\stack.psm1 -DisableNameChecking
# initialize internal state
Reset-TestSuite

Export-ModuleMember -Function @(
    'Reset-TestSuite'
    'New-Block'
    'New-Test'
    'New-EachTestSetup'
    'New-EachTestTeardown'
    'New-OneTimeTestSetup'
    'New-OneTimeTestTeardown'
    'New-EachBlockSetup'
    'New-EachBlockTeardown'
    'New-OneTimeBlockSetup'
    'New-OneTimeBlockTeardown'
    'Invoke-Test'

    'Where-Failed'
    'View-Flat'

    'New-FilterObject'
    'New-PluginObject'
    'New-TestContainerObject'
)