

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

    Write-Host -ForegroundColor Blue $Message
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
    if ((Is-Discovery) -or (Is-DiscoverySkipped)) {   
        v "Adding block $Name to discovered blocks"
        $block = New-BlockObject -Name $Name -Path $path
        # we attach the current block to the parent
        Add-Block -Block $block
    }

    $previousBlock = Get-CurrentBlock
    if ($null -eq $block) { 
        # we have run discovery and now
        # we are executing tests 
        # so we need to find where we are
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
            # this would be block setup and teardown
            $setup =  {}
            $teardown = {}
            $result = Invoke-ScriptBlock -ScriptBlock $ScriptBlock -Setup $setup -Teardown $teardown
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
        [ScriptBlock] $ScriptBlock
    )

    v "Entering test $Name"
    Push-Scope -Scope (New-Scope -Name $Name -Hint Test)
    try {
        $path = Get-ScopeHistory | % Name
        v "Entering path $($path -join '.')"
        
        # do this setup when we are running discovery
        # or when we skipped it
        if ((Is-Discovery) -or (Is-DiscoverySkipped)) {
            Add-Test -Test (New-TestObject -Name $Name -Path $path)
            v "Added test '$Name'"
        }

        if (-not (Is-Discovery)) {
            $test = Find-CurrentTest -Name $Name -ScriptBlock $ScriptBlock
            if (Is-TestExcluded -Test $test) {
                v "Test is excluded from run, returning"
                return
            }

            $block = Get-CurrentBlock
            
            $eachSetup = $block.EachTestSetup | or {}
            $eachTeardown = $block.EachTestTeardown | or {}
            
            v "Running test '$Name'."
            
            $oneTimeTestSetupResult = $null
            if ($null -ne $block.OneTimeTestSetup) {
                # todo: emulate break by skipping the body when break was used in allSetup
                # todo: emulate finally by skipping the body when the setup fails and jumping directly to teardown
                # we want to get the values into the current scope (a body of a 'block')
                # so we use -SameScope and -NoNewScope to dot source both the provided 
                # scriptBlock (which contains setup) and the wrapper scriptblock (which provides
                # extra scope when we need to prevent variables from leaking)
                $oneTimeTestSetupResult = Invoke-ScriptBlock -ScriptBlock $block.OneTimeTestSetup -SameScope -NoNewScope
            }
            # invokes the body of the test
            $result = Invoke-ScriptBlock -ScriptBlock $ScriptBlock -Setup $block.EachTestSetup -Teardown $block.EachTestTeardown -SameScope

            $oneTimeTestTeardownResult = $null
            if ($null -ne $block.OneTimeTestTeardown) {
                $oneTimeTestTeardownResult = Invoke-ScriptBlock -ScriptBlock $block.OneTimeTestTeardown -SameScope -NoNewScope
            }

            $standardOutput = combineNonNull ($oneTimeTestSetupResult | tryExpandProperty StandardOutput) $result.StandardOutput ($oneTimeTestTeardownResult | tryExpandProperty StandardOutput)

            # todo: this migh change if one time setup or teardown fails
            $test.Executed = $true 
            # todo: this migh change if one time setup or teardown fails
            $test.Passed = ($oneTimeTestSetupResult | tryExpandProperty Success | or $true) -and $result.Success -and ($oneTimeTestTeardownResult | tryExpandProperty Success | or $true)
            $test.StandardOutput = $standardOutput
            #todo: combine errors? 
            $test.ErrorRecord = $result.ErrorRecord
            
            

            if (-not $oneTimeTestTeardownResult.Success) { v "Test $Name failed with $($oneTimeTestTeardownResult.ErrorRecord.Exception)"}
            if (-not $oneTimeTestSetupResult.Success) { v "Test $Name failed with $($oneTimeTestSetupResult.ErrorRecord.Exception)"}
            if (-not $result.Success) { v "Test $Name failed with $($result.ErrorRecord.Exception)"}
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
    [CmdletBinding(DefaultParameterSetName = "Empty")]
    param (
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock
    )

    (Get-CurrentBlock).OneTimeTestSetup = $ScriptBlock
}

# endpoint for adding a teardown for all tests in the block
function New-OneTimeTestTeardown {
    [CmdletBinding(DefaultParameterSetName = "Empty")]
    param (
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock
    )

    (Get-CurrentBlock).OneTimeTestTeardown = $ScriptBlock
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
        $Block = @()
    )

    New-PSObject -Type DiscoveredBlock @{
        Name = $Name
        Path = $Path
        # all tests within the block
        Tests = $Test
        # setup that will be run before every test
        EachTestSetup = $EachTestSetup
        OneTimeTestSetup = $OneTimeTestSetup
        EachTestTeardown = $EachTestTeardown
        OneTimeTestTeardown = $OneTimeTestTeardown
        Blocks = @()
        Executed = $false
        Passed = $false
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

    (Get-CurrentBlock).Blocks += $Block
}

function Is-Discovery {
    $script:discovery
}

function Is-DiscoverySkipped {
    $script:discoverySkipped
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
        [Parameter(Mandatory = $true )]
        [ScriptBlock] $ScriptBlock,
        [ScriptBlock] $Setup,
        [ScriptBlock] $Teardown,
        # setup, body and teardown will all run (be-dotsourced into) 
        # the same scope
        [Switch] $SameScope,
        # will dot-source the wrapper scriptblock instead of invoking it
        # so in combination with the SameScope switch we are effectively
        # running the code in the current scope
        [Switch] $NoNewScope
    )

    # this is what the code below does
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

    # a similar solution was $SessionState.PSVariable.Set('a', 10)
    # but that sets the variable for all "scopes" in the current
    # scope so the value persist after the original has run which
    # is not correct,

    $scriptBlockWithContext = {
        # THIS RUNS IN USER SCOPE, BE CAREFUL WHAT YOU PUBLISH AND CONSUME!
        param($pester_context)
        if ($pester_context) {
            try {
                if ($null -ne $pester_context.Setup) {
                    . $pester_context.Setup
                }
                if ($pester_context.SameScope) {
                    . $pester_context.ScriptBlock
                }
                else {
                    & $pester_context.ScriptBlock
                }
            }
            finally {
                if ($null -ne $pester_context.Teardown) {
                    . $pester_context.Teardown
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
            $standardOutput = if ($NoNewScope) {
                    . $scriptBlockWithContext @{ 
                        ScriptBlock = $ScriptBlock
                        Setup = $Setup
                        Teardown = $Teardown
                        SameScope = $SameScope 
                    }
                } 
                else {
                    & $scriptBlockWithContext @{ 
                        ScriptBlock = $ScriptBlock
                        Setup = $Setup
                        Teardown = $Teardown
                        SameScope = $SameScope 
                    }
                }
            # if the code reaches here we did not break
            $break = $false
        } while ($false)
    }
    catch {
        $success = $false
        $err = $_
    }

    return New-PSObject -Type ScriptBlockInvocationResult @{
        Success = $success
        ErrorRecord = $err
        StandardOutput = $standardOutput
        Break = $break
        Setup = $Setup
        Teardown = $Teardown
        ScriptBlock = $ScriptBlock
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

    $result = Start-Test $ScriptBlock
    $result
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
# from collections so e.g. combineNonNull @(1,$null) @(1,2,3) $null $null 10
# returns 1, $null, 1, 2, 3, 10
function combineNonNull {
    
    foreach ($arg in $args) {
       
        $arr = @($arg)
        if ($null -ne $arg -and $arr.Length -gt 0) {
            foreach ($a in $arr) {
                $a
            }
        }
    }
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