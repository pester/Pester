param (
    [Parameter(Mandatory)]
    [string] $ApiKey,
    # TODO path parameter is currently unused and throws warning
    [Parameter(Mandatory)]
    [string] $Path
)

$VerbosePreference = 'Continue'
$ErrorActionPreference = 'Stop'
$baseDir = $PSScriptRoot

try {
    $buildDir = "$baseDir\build\psgallery\Pester"
    Write-Verbose 'Importing PowerShellGet module'
    $psGet = Import-Module PowerShellGet -PassThru -Verbose:$false
    & $psGet { [CmdletBinding()] param () Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -BootstrapNuGetExe -Force }

    Write-Output 'Publishing module to PowerShellGet'
    $null = Publish-Module -Path $buildDir -NuGetApiKey $ApiKey -Confirm:$false -Force
}
catch {
    Write-Error -ErrorRecord $_
    exit 1
}
