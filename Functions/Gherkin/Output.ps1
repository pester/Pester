function Write-Feature {
  param (
    [Parameter(mandatory=$true, valueFromPipeline=$true)]
    $Feature
  )
  process {
    Write-Host "Feature:" $Feature.Keyword $Feature.Name -ForegroundColor Magenta
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
    Write-Host
    Write-Host "   ${Name}:" $Scenario.Name -ForegroundColor Magenta
    $Scenario.Description -split "\n" | % {
      Write-Host (" " * $Name.Length) $Scenario.Description -ForegroundColor Magenta
    }
  }
}
