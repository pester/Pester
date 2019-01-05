Get-Module Pester.Runtime, Pester.RSpec | Remove-Module
Import-Module $PSScriptRoot/../Pester.Runtime.psm1 -DisableNameChecking
Import-Module $PSScriptRoot/../Pester.RSpec.psm1 -DisableNameChecking

$files = Pester.RSpec\Find-RSpecTestFile $PSScriptRoot
$fileContainers = $files | foreach { Pester.Runtime\New-BlockContainerObject -Path $_.FullName }
$scriptBlockContainer = New-BlockContainerObject -ScriptBlock { New-Block "Same name" {
        New-Test "Same name" {
            "scriptblock3"
        } -Tag sb3
    }

    New-Block "block 3" {
        New-Test "test 3" {

        }
    }
}

function Fold-Block {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $Block, 
        $OnBlock = {}, 
        $OnTest = {}, 
        $Accumulator
    )
    process {
        foreach ($b in $Block) {
            $Accumulator = & $OnBlock $Block $Accumulator
            foreach ($test in $Block.Tests) {
                $Accumulator = &$OnTest $test $Accumulator
            }

            foreach ($b in $Block.Blocks) {
               Fold-Block -Block $b -OnTest $OnTest -OnBlock $OnBlock -Accumulator $Accumulator
            }
        }
    }
}

function Fold-Container {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Container,
        $OnContainer = {},
        $OnBlock = {},
        $OnTest = {},
        $Accumulator
    )

    process {
        foreach ($c in $Container) { 
            $Accumulator = & $OnContainer $c $Accumulator
            foreach ($block in $c.Blocks) {
                Fold-Block -Block $block -OnBlock $OnBlock -OnTest $OnTest -Accumulator $Accumulator
            }
        }
    }
}
function shouldRun ($bool) { if ($bool) { '✔' } else {'❌'}}




$containers = @($fileContainers) + $scriptBlockContainer

$filter = (New-FilterObject -Tag sb3)
$found = Pester.Runtime\Find-Test $containers -Filter $filter

Fold-Container -Container $found `
    -OnContainer {
        param($container, $acc)
        $path = if ($container.Type -eq 'ScriptBlock') { $container.Content.File } else { $container.content.FullName }
        Write-Host -ForegroundColor Magenta $container.type - $path
    } `
    -OnBlock { param($block, $acc) Write-Host -ForegroundColor Cyan ('-' * $acc * 2) (shouldRun $block.ShouldRun) $block.Name; $acc + 1 } `
    -OnTest { param ($test, $acc) Write-Host -ForegroundColor Green "$(' ' * ($acc*2))-> $(shouldRun $test.ShouldRun) $($test.Name)" }


$runResult = Pester.Runtime\Invoke-Test -BlockContainer $containers -Filter $filter
$runResult | Fold-Container -OnTest { param($test) Write-Host $test.standardoutput  }