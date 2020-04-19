param (
    [Parameter(Mandatory)]
    [string] $ApiKey
)


$VerbosePreference = 'Continue'
$ErrorActionPreference = 'Stop'
$baseDir = $PSScriptRoot

try {
    $buildDir = "$baseDir\build\psgallery\Pester"
    Write-Verbose 'Importing PowerShellGet module'
    $psGet = Import-Module PowerShellGet -PassThru -Verbose:$false
    & $psGet { [CmdletBinding()] param () Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -BootstrapNuGetExe -Force }

    Write-Host 'Publishing module to PowerShellGet'
    $null = Publish-Module -Path $buildDir -NuGetApiKey $ApiKey -Confirm:$false
}
catch {
    Write-Error -ErrorRecord $_
    exit 1
}
