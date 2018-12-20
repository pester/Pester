

Get-Item function:wrapper -ErrorAction SilentlyContinue | remove-item

Get-Module P, Pester | Remove-Module 
Import-Module Pester -MinimumVersion 4.4.3
New-Module -Name P {
    $script:beforeAlls = @{}
    $script:beforeEaches = @{}
    $script:Discovery = $true

    function d {
        param(
            [String] $Name, 
            [ScriptBlock] $Block
        )
        if ($script:Discovery) {
            Write-Host "Found block $Name" -ForegroundColor Cyan
            & $Block
        }
        else {
            Write-Host "Executing block $Name" -ForegroundColor Green
            if ($script:beforeAlls.contains($name)) {
                &$script:beforeAlls[$Name]
            }
            & $Block
        }



    }

    function ba {
        param(
            [ScriptBlock] $Block
        )

        if ($script:Discovery) {
            $script:beforeAlls[$Name] = $Block
        }
    }

    function be {
        param(
            [ScriptBlock] $Block
        )

        if ($script:Discovery) {
            $script:beforeEaches[$Name] = $Block
        }
    }

    function i {
        param(
            [String] $Name, 
            [ScriptBlock] $Test
        )
        if ($script:Discovery) {
            Write-Host "Found test $Name" -ForegroundColor Cyan
        }
        else {
            Write-Host "Executing test $Name" -ForegroundColor Green
            if ($script:beforeAlls.contains($name)) {
                &$script:beforeAlls[$Name]
            }
            & $Test
        }
    }

    function Invoke-P {
        param(
            [ScriptBlock] $Suite
        )

        $script:Discovery = $true
    
        & {
            param ($phase)
            . $Suite
            # this variable should go away somehog
            $script:Discovery = $false
            & $Suite
        }
    }

    function Work {
        param (
            [ScriptBlock]
            $Work
        )
        if ($script:Discovery) 
        {
            Write-Host "Skipping this piece of code { $($Work.ToString().Trim()) }, because we are Found tests." -ForegroundColor Yellow
        }
        else 
        {
            &$Work
        }
    }

    # dot-sources a piece of script during the Discovery pass so all possible dependencies
    # are in scope and we can discover even tests that are "hidden" in custom functions
    # this function must be defined to run without additional scope (like the Mock prototype), 
    # atm I will just return a populated or empty scriptBlock and dot-source it to get the same effect
    function TestDependency {
        param (
            [string]
            $Path
        )
        if ($script:Discovery) 
        {
            if (-not (Test-Path $Path)) {
                throw "Test dependency path does not exist"
            }
            Write-Host Importing $Path
            $Path
        }
        else{
            {}
        }
    }

    # dot-sources a piece of script during the Run pass so all possible dependencies
    # to the i blocks are in scope run the tests
    # this function must be defined to run without additional scope (like the Mock prototype), 
    # atm I will just return a populated or empty scriptBlock and dot-source it to get the same effect
    function Dependency {
        param (
            [string]
            $Path
        )
        if ($script:Discovery) 
        {
            {}
        }
        else{
            if (-not (Test-Path $Path)) {
                throw "dependency path does not exist"
            }
            Write-Host Importing $Path
            $Path
        }
    }
} | Import-Module


# okay so the idea here is that we run the scripts twice, in the first pass we import all the test dependencies 
# those dependencies might be non-existent if the user does not do anything fancy, like wrapping the IT blocks into 
# a custom function. This way we know that the dependencies are available during the discovery phase, and hopefully they are
# not expensive to run


# in the second pass we run as Dependencies and invoke all describes again and also invoke all its this way we first discovered the 
# test accumulated all the setups and teardowns of all blocks without using ast and we can invoke them in the correct scope without 
# unbinding them

# further more we possibly know that we ended the run so we can also print the summary??? :D

# run
Invoke-P {
    . (TestDependency -Path $PSScriptRoot\wrapper.ps1)
    
    wrapper "kk" { write-host "wrapped test"}
    d "top" { 
        ba {
            Write-Host "this is ba" -ForegroundColor Blue
        }
        be {
            Write-Host "this is be" -ForegroundColor Blue
        }
        Work {
            Write-Host "offending piece of code" -ForegroundColor Red
        }
        d "l1" {
            d "l2" {
                i "test 1" {
                    Write-Host "I run"
                }

                i "test 1" {
                    Write-Host "I run"
                }
            }
        }
    }
}