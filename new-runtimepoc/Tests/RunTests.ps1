Get-Module Pester.Runtime, Pester.RSpec | Remove-Module
Import-Module $PSScriptRoot/../Pester.Runtime.psm1 -DisableNameChecking
Import-Module $PSScriptRoot/../Pester.RSpec.psm1 -DisableNameChecking

$files = Pester.RSpec\Find-RSpecTestFile $PSScriptRoot
$fileContainers = $files | foreach { Pester.Runtime\New-BlockContainerObject -Path $_.FullName }
$scriptBlockContainer = New-BlockContainerObject -ScriptBlock { New-Block "Same name" {
        New-Test "Same name" {
            Write-host "sleeping"
            Start-Sleep -Seconds 1
            "scriptblock3"
        } -Tag sb3
    }

    New-Block "block 3" {
        New-Test "test 3 4" {
            Start-Sleep -Milliseconds 350
        }


        New-Block "block 4" {
            
            New-Test "test 6" {
                Start-Sleep -Milliseconds 500 
            }
        }
        New-Test "test 3" {
            Start-Sleep -Milliseconds 350
        }

        New-Test "test 4" {
            throw
        }

        New-Test "test 5" {

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
function yOrN ($bool) { if ($bool) { '✔' } else { '✖' }}




$containers = @($fileContainers) + $scriptBlockContainer
# HACK!
$containers = @($scriptBlockContainer)

$filter = (New-FilterObject -Tag sb3)
$found = Pester.Runtime\Find-Test $containers -Filter $filter

# Fold-Container -Container $found `
#     -OnContainer {
#         param($container, $acc)
#         $path = if ($container.Type -eq 'ScriptBlock') { $container.Content.File } else { $container.content.FullName }
#         Write-Host -ForegroundColor Magenta $container.type - $path
#     } `
#     -OnBlock { param($block, $acc) Write-Host -ForegroundColor Cyan ('-' * $acc * 2) (yOrN $block.ShouldRun) $block.Name; $acc + 1 } `
#     -OnTest { param ($test, $acc) Write-Host -ForegroundColor Yellow "$(' ' * ($acc*2))-> $(yOrN $test.ShouldRun) $($test.Name)" }


$runResult = Pester.Runtime\Invoke-Test -BlockContainer $containers #  -Filter $filter
$runResult | Fold-Container -OnTest { param($test) Write-Host $test.standardoutput  }


$runResult | Fold-Container `
    -OnContainer {
        param($container, $acc)
        $path = if ($container.Type -eq 'ScriptBlock') { $container.Content.File } else { $container.content.FullName }
        Write-Host -ForegroundColor Magenta $container.type - $path "$($container.AggregatedDuration.TotalMilliseconds)" ms with overhead "$($container.FrameworkDuration.TotalMilliseconds)" ms
    } `
    -OnBlock { param($block, $acc) Write-Host -ForegroundColor Cyan ('-' * $acc * 2) (yOrN $block.AggregatedPassed) (yOrN $block.Passed) $block.Name "$($block.AggregatedDuration.TotalMilliseconds)" ms with overhead "$($block.FrameworkDuration.TotalMilliseconds)" ms;  $acc + 1 } `
    -OnTest { param ($test, $acc) Write-Host -ForegroundColor Yellow "$(' ' * ($acc*2))-> $(yOrN $test.Passed) $($test.Name) $($test.Duration.TotalMilliseconds) ms" with overhead "$($test.FrameworkDuration.TotalMilliseconds)" ms }