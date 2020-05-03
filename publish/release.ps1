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

pwsh -f "$PSScriptRoot/../build.ps1 -clean"
if ($LASTEXITCODE -ne 0) {
    throw "build failed!"
}

pwsh -f "$PSSCriptRoot/../test.ps1 -nobuild"
if ($LASTEXITCODE -ne 0) {
    throw "test failed!"
}

& "$PSScriptRoot/signModule.ps1" -Thumbprint $CertificateThumbprint -Path "$PSScriptRoot/../bin"



$psGalleryDir = "$PSScriptRoot/../tmp/PSGallery/Pester/"
if (Test-Path $psGalleryDir) {
    Remove-Item -Recurse -Force $psGalleryDir
}
$null = New-Item -ItemType Directory -Path $psGalleryDir
Copy-Item "$PSScriptRoot/../bin/*" $psGalleryDir -Recurse

$files = @(
"nunit_schema_2.5.xsd"
"junit_schema_4.xsd"
"Pester.psd1"
"Pester.psm1"
"report.dtd"
"Pester\bin\net452\Pester.dll"
"Pester\bin\net452\Pester.pdb"
"Pester\bin\netstandard2.0\Pester.dll"
"Pester\bin\netstandard2.0\Pester.pdb"
"en-US\about_BeforeEach_AfterEach.help.txt"
"en-US\about_Mocking.help.txt"
"en-US\about_Pester.help.txt"
"en-US\about_Should.help.txt"
"en-US\about_TestDrive.help.txt"
)

$notFound = @()
foreach ($f in $files) {
    if (-not (Test-Path "$psGalleryDir/$f")) {
        $notFound += $f
    }
}

if (0 -lt $notFound.Count) {
    throw "Did not find files:`n$($notFound -join "`n")"
}
else {
    "Found all files!"
}



Publish-Module -Path $psGalleryDir -NuGetApiKey $PsGalleryApiKey -Verbose
#.\buildNugetPackage.ps1
# .\buildPSGalleryPackage.ps1


# .\publishPSGalleryPackage.ps1 $PsGalleryApiKey
# publish nuget
# publish chocolatey
