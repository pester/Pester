[Diagnostics.CodeAnalysis.SuppressMessageAttribute("Pester.BuildAnalyzerRules\Measure-SafeCommands", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidOverwritingBuiltInCmdlets", "Get-FileHash")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "")]
param (
    [Parameter(Mandatory)]
    [string] $ApiKey,
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

    Write-Host 'Publishing module to PowerShellGet'
    $null = Publish-Module -Path $buildDir -NuGetApiKey $ApiKey -Confirm:$false -Force
}
catch {
    Write-Error -ErrorRecord $_
    exit 1
}
