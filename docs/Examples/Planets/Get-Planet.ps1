# This is not the best file to start from,
# open Get-Planet.Tests.ps1 as well :)


function Get-Planet ([string]$Name = '*') {
    $planets = @(
        @{ Name = 'Mercury' }
        @{ Name = 'Venus'   }
        @{ Name = 'Earth'   }
        @{ Name = 'Mars'    }
        @{ Name = 'Jupiter' }
        @{ Name = 'Saturn'  }
        @{ Name = 'Uranus'  }
        @{ Name = 'Neptune' }
    ) | foreach { New-Object -TypeName PSObject -Property $_ }

    $planets | where { $_.Name -like $Name }
}

# The code above uses New-Object instead of the [PSCustomObject]
# you saw in the readme file. This is only to keep the example
# compatible with PowerShell version 2.
