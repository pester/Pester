Set-StrictMode -version 2.0

function Cleanup {
    Clear-Mocks

    if (Test-Path $TestDrive) {
        Microsoft.PowerShell.Management\Remove-Item $TestDrive -Recurse -Force
        Remove-PSDrive -Name TestDrive -Scope Global -Force
    }
}

