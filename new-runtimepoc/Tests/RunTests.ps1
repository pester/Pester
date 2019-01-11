Get-Module Pester.Runtime, Pester.RSpec, Pester.Utility | Remove-Module
Import-Module $PSScriptRoot/../Pester.Runtime.psm1 -DisableNameChecking
Import-Module $PSScriptRoot/../Pester.RSpec.psm1 -DisableNameChecking
Import-Module $PSScriptRoot/../Pester.Utility.psm1 -DisableNameChecking

$files = Pester.RSpec\Find-RSpecTestFile $PSScriptRoot
$fileContainers = $files | foreach { Pester.Runtime\New-BlockContainerObject -Path $_.FullName }
$scriptBlockContainer = New-BlockContainerObject -ScriptBlock { 
    Add-FrameworkDependency { 
        Write-Host -ForegroundColor Yellow "IMPORTING: Framework dependency"
        function Wrapper2 ($name, $sb) {
            Write-Host -ForegroundColor Yellow I am just a stupid wrapper that adds wrapped to name of a test 
            
            New-Test "WRAPPED: $name" $sb
        }
    }

    Add-Dependency -SessionState $ExecutionContext.SessionState { 
        Write-Host -ForegroundColor Yellow "IMPORTING: Run dependency"
        $Something = 10
    }

    New-Block "Same name" {
        New-Test "Same name" {
            Write-host "sleeping"
            Start-Sleep -Seconds 1
            "scriptblock3"
        } -Tag sb3
    }

    New-Block "block 3" {
        New-Test "test 3 4" {
            Start-Sleep -Milliseconds 50
        }


        New-Block "block 4" {
            
            New-Test "test 6" {
                Start-Sleep -Milliseconds 30
            }
        }

        Wrapper2 "test 3" {
            Start-Sleep -Milliseconds 40
        }

        New-Test "test 4" {
            throw
        }

        New-Test "test 5" {
            Write-Host "-something -" $Something
            if ($Something -ne 10 ) { throw "fail" }
        }
    }
}

function yOrN ($bool) { if ($bool) { 'Y' } else { 'N' }}




$containers = @($fileContainers) + $scriptBlockContainer

$filter = (New-FilterObject -Tag sb3)
$found = Pester.Runtime\Find-Test -SessionState $ExecutionContext.SessionState $containers -Filter $filter

# Fold-Container -Container $found `
#     -OnContainer {
#         param($container, $acc)
#         $path = if ($container.Type -eq 'ScriptBlock') { $container.Content.File } else { $container.content.FullName }
#         Write-Host -ForegroundColor Magenta $container.type - $path
#     } `
#     -OnBlock { param($block, $acc) Write-Host -ForegroundColor Cyan ('-' * $acc * 2) (yOrN $block.ShouldRun) $block.Name; $acc + 1 } `
#     -OnTest { param ($test, $acc) Write-Host -ForegroundColor Yellow "$(' ' * ($acc*2))-> $(yOrN $test.ShouldRun) $($test.Name)" }


$runResult = Pester.Runtime\Invoke-Test -SessionState $ExecutionContext.SessionState -BlockContainer $containers #  -Filter $filter
$runResult | Fold-Container -OnTest { param($test) Write-Host $test.standardoutput  }


 function write-errs { 
    param($errorRecord) 
    if ($null -eq $errorRecord -or $errorRecord.Length -eq 0) { return }
    $o = foreach ($e in $errorRecord) {
        "$e"
        $e.InvocationInfo.LocationMessage
        $e.ScriptStackTrace | Out-String | foreach { $_ -replace '\s*line\s+(\d+)','$1'}
    }
    Write-Host $o -ForegroundColor Red
 }
$runResult | Fold-Container `
    -OnContainer {
        param($container, $acc)
        $path = if ($container.Type -eq 'ScriptBlock') { $container.Content.File } else { $container.content.FullName }
        Write-Host -ForegroundColor Magenta $container.type - Executed: $(yOrN $container.Executed) Passed: $(yOrN $container.Passed) AggregatedPassed: (yOrN $container.AggregatedPassed) $path "$($container.AggregatedDuration.TotalMilliseconds)" ms with overhead "$($container.FrameworkDuration.TotalMilliseconds)" ms
    } `
    -OnBlock { param($block, $acc) Write-Host -ForegroundColor Cyan ('-' * $acc * 2) ShouldRun: $(yOrN $block.ShouldRun) Executed: $(yOrN $block.Executed) Passed: $(yOrN $block.Passed) AggregatedPassed: (yOrN $block.AggregatedPassed) $block.Name "$($block.AggregatedDuration.TotalMilliseconds)" ms with overhead "$($block.FrameworkDuration.TotalMilliseconds)" ms; (Write-Errs $block.ErrorRecord); $acc + 1 } `
    -OnTest { param ($test, $acc) Write-Host -ForegroundColor Yellow "$(' ' * ($acc*2))-> ShouldRun: $(yOrN $test.ShouldRun) Executed: $(yOrN $test.Executed) Passed: $(yOrN $test.Passed) $($test.Name) $($test.Duration.TotalMilliseconds) ms" with overhead "$($test.FrameworkDuration.TotalMilliseconds)" ms (Write-Errs $test.ErrorRecord); $acc}