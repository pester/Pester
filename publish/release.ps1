# build should provide '%system.teamcity.build.checkoutDir%'
param (
    [String] $CertificateThumbprint = '7B9157664392D633EDA2C0248605C1C868EBDE43',
    # [Parameter(Mandatory)]
    # [String] $NugetApiKey,
    # [String] $ChocolateyApiKey,
    [Parameter(Mandatory)]
    [String] $PsGalleryApiKey
)

$ErrorActionPreference = 'Stop'
# run this in seperate instance otherwise Pester.dll is loaded and the subsequent build will fail
# $process = Start-Process powershell -ArgumentList "-c", ".\testRelease.ps1 -LocalBuild" -NoNewWindow -Wait -PassThru

# if ($process.ExitCode -ne 0) {
#     throw "Testing failed with exit code $($process.ExitCode)."
# }

#.\getNugetExe.ps1
#.\cleanUpBeforeBuild.ps1
# & "$PSSCriptRoot/../test.ps1"
& "$PSScriptRoot/signModule.ps1" -Thumbprint $CertificateThumbprint -Path "$PSScriptRoot/../bin"

$psGalleryDir = "$PSScriptRoot/../tmp/PSGallery/Pester/"

if (Test-Path $psGalleryDir) {
    Remove-Item -Recurse -Force $psGalleryDir
}

$null = New-Item -ItemType Directory -Path $psGalleryDir
Copy-Item "$PSScriptRoot/../bin/*" $psGalleryDir -Recurse -Verbose

Publish-Module -Path $psGalleryDir -NuGetApiKey $PsGalleryApiKey -Verbose
#.\buildNugetPackage.ps1
# .\buildPSGalleryPackage.ps1


# .\publishPSGalleryPackage.ps1 $PsGalleryApiKey
# publish nuget
# publish chocolatey
