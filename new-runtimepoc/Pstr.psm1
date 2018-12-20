$script:root = $null
$script:currentBlock = $null
#$script:discovery = $true

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

function Find-Test {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock,
        [String] $DefaultBlockName = "Root"
    )
    
   $script:currentBlock = $script:root = New-BlockObject -Name $DefaultBlockName
    & $ScriptBlock

    $script:root
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

    $block = New-BlockObject -Name $Name
    # we attach the current block to the parent
    Add-Block -Block $block
    # and then progress to the next block that might 
    # or might not be defined within the body of this 
    # block
    $previousBlock = Get-CurrentBlock
    Set-CurrentBlock -Block $block 
    try {
        & $ScriptBlock
    }
    finally {
        Set-CurrentBlock -Block $previousBlock
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

   #if ($script:discovery) {
        Add-Test -Test (New-TestObject -Name $Name)
    #}
}

# endpoint for adding a setup for each test in the block
function New-EachTestSetup {
    param (
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock
    )

    (Get-CurrentBlock).EachTestSetup = $ScriptBlock
}

# endpoint for adding a setup for all tests in the block
function New-AllTestSetup {
    [CmdletBinding(DefaultParameterSetName = "Empty")]
    param (
        [Parameter(Mandatory=$true)]
        [ScriptBlock] $ScriptBlock
    )

    (Get-CurrentBlock).AllTestSetup = $ScriptBlock
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

    (Get-CurrentBlock).Tests += New-TestObject -Name $Name
}

function New-TestObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String] $Name
    )

    New-PSObject -Type DiscoveredTest @{
        Name = $Name
    }
}

function New-BlockObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String] $Name,
        $Test = @(),
        [ScriptBlock] $EachTestSetup,
        [ScriptBlock] $AllTestSetup,
        $Block = @()
    )

    New-PSObject -Type DiscoveredBlock @{
        Name = $Name
        # all tests within the block
        Tests = $Test
        # setup that will be run before every test
        EachTestSetup = $EachTestSetup
        AllTestSetup = $AllTestSetup
        Blocks = @()
    }
}

function Add-Block {
    param (
        [Parameter(Mandatory=$true)]
        [PSTypeName("DiscoveredBlock")]
        $Block
    )

    (Get-CurrentBlock).Blocks += $Block
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