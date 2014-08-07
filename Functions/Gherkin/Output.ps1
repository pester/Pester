function Write-Feature {
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $Feature
    )
    process {
        Write-Host "Feature:" $Feature.Name -ForegroundColor Magenta
        $Feature.Description -split "\n" | % {
            Write-Host "        " $_ -ForegroundColor Magenta
        }
    }
}

function Write-Scenario {
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $Scenario
    )
    process {
        $Name = $Scenario.GetType().Name
        Microsoft.PowerShell.Utility\Write-Host
        Microsoft.PowerShell.Utility\Write-Host "   ${Name}:" $Scenario.Name -ForegroundColor Magenta
        $Scenario.Description -split "\n" | % {
            Microsoft.PowerShell.Utility\Write-Host (" " * $Name.Length) $Scenario.Description -ForegroundColor Magenta
        }
    }
}

function Write-TestResult {
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $TestResult
    )

    process {
        $testDepth = if ( $TestResult.Context ) { 4 } elseif ( $TestResult.Describe ) { 1 } else { 0 }

        $margin = " " * $TestDepth
        $error_margin = $margin + "  "
        $output = $TestResult.name
        $humanTime = Get-HumanTime $TestResult.Time.TotalSeconds

        if($TestResult.Passed)
        {
            "$margin[+] $output $humanTime" | Microsoft.PowerShell.Utility\Write-Host -ForegroundColor DarkGreen
        }
        elseif($null -eq $TestResult.Time) {
            "$margin[?] $output $humanTime" | Microsoft.PowerShell.Utility\Write-Host -ForegroundColor Yellow
        }
        else {
            "$margin[-] $output $humanTime" | Microsoft.PowerShell.Utility\Write-Host -ForegroundColor red
            Microsoft.PowerShell.Utility\Write-Host -ForegroundColor red $($TestResult.failureMessage -replace '(?m)^',$error_margin)
            Microsoft.PowerShell.Utility\Write-Host -ForegroundColor red $($TestResult.stackTrace -replace '(?m)^',$error_margin)
        }
    }
}

function Write-TestReport
{
    param (
        [Parameter(mandatory=$true, valueFromPipeline=$true)]
        $PesterState
    )

    Microsoft.PowerShell.Utility\Write-Host "Tests completed in $(Get-HumanTime $PesterState.Time.TotalSeconds)"

    $Success, $Failure = if($PesterState.FailedCount -gt 0) { "White", "Red" } else { "DarkGreen", "White" }
    Microsoft.PowerShell.Utility\Write-Host "Passed: $($PesterState.PassedCount) " -Fore $Success -NoNewLine
    Microsoft.PowerShell.Utility\Write-Host "Failed: $($PesterState.FailedCount) " -Fore $Failure
}