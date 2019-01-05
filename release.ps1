# build should provide '%system.teamcity.build.checkoutDir%'
param (
    [Parameter(Mandatory)]
    [String] $CertificateThumbprint,
    [Parameter(Mandatory)]
    [String] $NugetApiKey,
    [String] $ChocolateyApiKey,
    [Parameter(Mandatory)]
    [String] $PsGalleryApiKey



)

.\updateGherkinLanguageFile.ps1

$ErrorActionPreference = 'Stop'
# run this in seperate instance otherwise Gherkin.dll is loaded and
$process = Start-Process powershell -ArgumentList "-c", ".\testRelease.ps1 -LocalBuild" -NoNewWindow -Wait -PassThru

if ($process.ExitCode -ne 0) {
    throw "Testing failed with exit code $($process.ExitCode)."
}

.\getNugetExe.ps1
.\cleanUpBeforeBuild.ps1
.\signModule.ps1 -Thumbprint $CertificateThumbprint
.\buildNugetPackage.ps1
.\buildPSGalleryPackage.ps1


# .\publishPSGalleryPackage.ps1 $PsGalleryApiKey
# publish nuget
# publish chocolatey
