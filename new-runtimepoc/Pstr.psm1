

$script:root = $null
$script:currentBlock = $null
$script:discovery = $false
$script:discoverySkipped = $false
$script:filter = $null

# resets the module state to the default
function Reset-TestSuite {
    v "Resetting internal state to default."
    $script:root = $null
    $script:discovery = $false
    $script:discoverySkipped = $true
    $script:currentBlock = $script:root = New-BlockObject -Name "Block"
    $script:filter = @()
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

   #  Write-Host -ForegroundColor Blue $Message
}

function Find-Test {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock
    )
    v "Starting test discovery."
    $script:discovery = $true
    $script:discoverySkipped = $false

    & $ScriptBlock

    $script:root
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
            v "Executing body of block $Name"

            $result = Invoke-ScriptBlock `
                -ScriptBlock $ScriptBlock `
                -OuterSetup  @( $previousBlock.OneTimeBlockSetup | hasValue )`
                -Setup @( $previousBlock.EachBlockSetup | hasValue ) `
                -Teardown @( $previousBlock.EachBlockTeardown | hasValue ) `
                -OuterTeardown @( $previousBlock.OneTimeBlockTeardown | hasValue ) `
                -NoNewScope

            $block.Executed = $true
            $block.Passed = 0 -eq $result.ErrorRecord.Length
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
        [ScriptBlock] $ScriptBlock
    )

    v "Entering test $Name"
    Push-Scope -Scope (New-Scope -Name $Name -Hint Test)
    try {
        $path = Get-ScopeHistory | % Name
        v "Entering path $($path -join '.')"

        # do this setup when we are running discovery
        if (Is-Discovery) {
            Add-Test -Test (New-TestObject -Name $Name -Path $path)
            v "Added test '$Name'"
        }
        else {
            $test = Find-CurrentTest -Name $Name -ScriptBlock $ScriptBlock
            if (Is-TestExcluded -Test $test) {
                v "Test is excluded from run, returning"
                return
            }

            $block = Get-CurrentBlock

            v "Running test '$Name'."

            
            # invokes the body of the test
            $result = Invoke-ScriptBlock `
                -OuterSetup @( $block.OneTimeTestSetup | where { $test.First } | hasValue ) `
                -Setup @( $block.EachTestSetup | hasValue ) `
                -ScriptBlock $ScriptBlock `
                -Teardown @( $block.EachTestTeardown | hasValue ) `
                -OuterTeardown @( $block.OneTimeTestTeardown | where { $test.Last } | hasValue ) `
                -NoNewScope

         

            $test.Executed = $true
            $test.Passed = 0 -eq $result.ErrorRecord.Length

            $test.StandardOutput = $result.StandardOutput

            $test.ErrorRecord = $result.ErrorRecord

            if (-not $result.Success) { Write-Host -ForegroundColor Red "Test $Name failed with $($result.ErrorRecord.Exception | Out-String)"}
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
    $script:currentBlock
}

function Set-CurrentBlock {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Block
    )

    $script:currentBlock = $Block
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
        [string[]] $Path
    )

    New-PSObject -Type DiscoveredTest @{
        Name = $Name
        Path = $Path
        Executed = $false
        Passed = $false
        StandardOutput = $null
        ErrorRecord = $null
        First = $false
        Last = $false
    }
}

function New-BlockObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String] $Name,
        [string[]] $Path,
        $Test = @(),
        [ScriptBlock] $EachTestSetup,
        [ScriptBlock] $OneTimeTestSetup,
        [ScriptBlock] $EachTestTeardown,
        [ScriptBlock] $OneTimeTestTeardown,
        [ScriptBlock] $EachBlockSetup,
        [ScriptBlock] $OneTimeBlockSetup,
        [ScriptBlock] $EachBlockTeardown,
        [ScriptBlock] $OneTimeBlockTeardown,
        $Block = @()
    )

    New-PSObject -Type DiscoveredBlock @{
        Name = $Name
        Path = $Path
        # all tests within the block
        Tests = $Test
        EachTestSetup = $EachTestSetup
        OneTimeTestSetup = $OneTimeTestSetup
        EachTestTeardown = $EachTestTeardown
        OneTimeTestTeardown = $OneTimeTestTeardown
        EachBlockSetup = $EachBlockSetup
        OneTimeBlockSetup = $OneTimeBlockSetup
        EachBlockTeardown = $EachBlockTeardown
        OneTimeBlockTeardown = $OneTimeBlockTeardown
        Blocks = @()
        Executed = $false
        Passed = $false
        First = $false
        Last = $false
        StandardOutput = $null
        ErrorRecord = $null
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
    $script:discovery
}

# test invocation
function Start-Test {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock
    )

    $script:discovery = $false
    # do we want this output?
    $null = & $ScriptBlock
    $script:root
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
        
        try {
            if ($null -ne $______context.OuterSetup -and $______context.OuterSetup.Length -gt 0) {
                foreach ($______current in $______context.OuterSetup) {
                    $______context.CurrentlyExecutingScriptBlock = $______current
                    . $______current
                }
            }

            & {
                try {

                    if ($null -ne $______context.Setup -and $______context.Setup.Length -gt 0) {
                        foreach ($______current in $______context.Setup) {
                            $______context.CurrentlyExecutingScriptBlock = $______current
                            . $______current
                        }
                    }

                    . $______context.ScriptBlock
                }
                catch {
                    $______context.ErrorRecord += $_
                }
                finally {
                    if ($null -ne $______context.Teardown -and $______context.Teardown.Length -gt 0) {
                        foreach ($______current in $______context.Teardown) {            
                            try {
                                $______context.CurrentlyExecutingScriptBlock = $______current
                                . $______current
                            }
                            catch {
                                $______context.ErrorRecord += $_
                            }
                        }
                    }
                }
            }
        }
        finally {
            if ($null -ne $______context.OuterTeardown -and $______context.OuterTeardown.Length -gt 0) {
                foreach ($______current in $______context.OuterTeardown) {
                    try {
                        $______context.CurrentlyExecutingScriptBlock = $______current
                        . $______current
                    }
                    catch {
                        $______context.ErrorRecord += $_
                    }
                }
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
    $paths = $filter | % { $_ -join '.' } | % {"`n$_"}
    v "Setting path filter with $($filter.Count) paths: $paths"
    $script:filter = $Filter
}

function Is-TestExcluded {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Test
    )

    if ($script:filter.Length -eq 0) {
        v "Test with path $fullTestPath is included, beause there is no filter"
        return $false
    }
    $fullTestPath = $Test.Path -join '.'
    $allPaths = $script:filter | % { $_ -join '.' }
    $include = $allPaths -contains $fullTestPath
    if ($include) {
        v "Test with path $fullTestPath is included"
    }
    else {
        v "Test with path $fullTestPath is exluded"

    }
    -not $include
}

function Invoke-Test {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock,
        $Filter
    )

    Reset-TestSuite
    if ($filter) {
        Set-Filter $filter
    }
    $found = Find-Test $ScriptBlock

    $script:currentBlock = $script:root
    PostProcess-Test $script:root

    $result = Start-Test $ScriptBlock
    $result
}

function PostProcess-Test {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $Block
    )

    $tests = $Block.Tests 
    if (any $tests) {
        $tests[0].First = $true
        $tests[-1].Last = $true
    }
    $blocks = $Block.Blocks
    if (any $blocks) {
        $blocks[0].First = $true
        $blocks[-1].Last = $true
        foreach($b in $blocks) {
            PostProcess-Test -Block $b
        }
    }
}

# initialize the internal state
Reset-TestSuite



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
function tryExpandProperty {
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
# $script:beforeAlls = @{}
# $script:beforeEaches = @{}
# $script:Discovery = $true

# function d {
#     param(
#         [String] $Name,
#         [ScriptBlock] $Block
#     )
#     if ($script:Discovery) {
#         Write-Host "Found block $Name" -ForegroundColor Cyan
#         & $Block
#     }
#     else {
#         Write-Host "Executing block $Name" -ForegroundColor Green
#         if ($script:beforeAlls.contains($name)) {
#             &$script:beforeAlls[$Name]
#         }
#         & $Block
#     }



# }

# function ba {
#     param(
#         [ScriptBlock] $Block
#     )

#     if ($script:Discovery) {
#         $script:beforeAlls[$Name] = $Block
#     }
# }

# function be {
#     param(
#         [ScriptBlock] $Block
#     )

#     if ($script:Discovery) {
#         $script:beforeEaches[$Name] = $Block
#     }
# }

# function i {
#     param(
#         [String] $Name,
#         [ScriptBlock] $Test
#     )
#     if ($script:Discovery) {
#         Write-Host "Found test $Name" -ForegroundColor Cyan
#     }
#     else {
#         Write-Host "Executing test $Name" -ForegroundColor Green
#         if ($script:beforeAlls.contains($name)) {
#             &$script:beforeAlls[$Name]
#         }
#         & $Test
#     }
# }

# function Invoke-P {
#     param(
#         [ScriptBlock] $Suite
#     )

#     $script:Discovery = $true

#     & {
#         param ($phase)
#         . $Suite
#         # this variable should go away somehog
#         $script:Discovery = $false
#         & $Suite
#     }
# }

# function Work {
#     param (
#         [ScriptBlock]
#         $Work
#     )
#     if ($script:Discovery)
#     {
#         Write-Host "Skipping this piece of code { $($Work.ToString().Trim()) }, because we are Found tests." -ForegroundColor Yellow
#     }
#     else
#     {
#         &$Work
#     }
# }

# # dot-sources a piece of script during the Discovery pass so all possible dependencies
# # are in scope and we can discover even tests that are "hidden" in custom functions
# # this function must be defined to run without additional scope (like the Mock prototype),
# # atm I will just return a populated or empty scriptBlock and dot-source it to get the same effect
# function TestDependency {
#     param (
#         [string]
#         $Path
#     )
#     if ($script:Discovery)
#     {
#         if (-not (Test-Path $Path)) {
#             throw "Test dependency path does not exist"
#         }
#         Write-Host Importing $Path
#         $Path
#     }
#     else{
#         {}
#     }
# }

# # dot-sources a piece of script during the Run pass so all possible dependencies
# # to the i blocks are in scope run the tests
# # this function must be defined to run without additional scope (like the Mock prototype),
# # atm I will just return a populated or empty scriptBlock and dot-source it to get the same effect
# function Dependency {
#     param (
#         [string]
#         $Path
#     )
#     if ($script:Discovery)
#     {
#         {}
#     }
#     else{
#         if (-not (Test-Path $Path)) {
#             throw "dependency path does not exist"
#         }
#         Write-Host Importing $Path
#         $Path
#     }
# }