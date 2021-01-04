# build should provide '%system.teamcity.build.checkoutDir%'
param (
    [Parameter(Mandatory)]
    [String] $PsGalleryApiKey,
    [String] $NugetApiKey,
    [String] $ChocolateyApiKey,
    [String] $GitHubUsername,
    [String] $GitHubToken,
    [String] $CertificateThumbprint = '7B9157664392D633EDA2C0248605C1C868EBDE43',
    [Switch] $Force
)

$ErrorActionPreference = 'Stop'

$bin = "$PSScriptRoot/../bin"

# checking the path first because I want to fail the script when I fail to remove all files
if (Test-Path $bin) {
    Remove-Item $bin -Recurse -Force
}

pwsh -noprofile -c "$PSScriptRoot/../build.ps1 -clean"
if ($LASTEXITCODE -ne 0) {
    throw "build failed!"
}

$m = Test-ModuleManifest $bin/Pester.psd1
$version = if ($m.PrivateData -and $m.PrivateData.PSData -and $m.PrivateData.PSData.PreRelease)
{
    "$($m.Version)-$($m.PrivateData.PSData.PreRelease)"
}
else {
    $m.Version
}

$isPreRelease = $version -match '-'

if (-not $isPreRelease -or $Force) {
    if ([string]::IsNullOrWhiteSpace($NugetApiKey)) {
        throw "This is stable release NugetApiKey is needed."
    }

    if ([string]::IsNullOrWhiteSpace($ChocolateyApiKey)) {
        throw "This is stable release ChocolateyApiKey is needed."
    }
}

pwsh -noprofile -c "$PSSCriptRoot/../test.ps1 -nobuild"
if ($LASTEXITCODE -ne 0) {
    throw "test failed!"
}


& "$PSScriptRoot/signModule.ps1" -Thumbprint $CertificateThumbprint -Path $bin


$files = @(
"nunit_schema_2.5.xsd"
"junit_schema_4.xsd"
"Pester.psd1"
"Pester.psm1"
"report.dtd"
"bin\net452\Pester.dll"
"bin\net452\Pester.pdb"
"bin\netstandard2.0\Pester.dll"
"bin\netstandard2.0\Pester.pdb"
"en-US\about_BeforeEach_AfterEach.help.txt"
"en-US\about_Mocking.help.txt"
"en-US\about_Pester.help.txt"
"en-US\about_Should.help.txt"
"en-US\about_TestDrive.help.txt"
)

$notFound = @()
foreach ($f in $files) {
    if (-not (Test-Path "$bin/$f")) {
        $notFound += $f
    }
}

if (0 -lt $notFound.Count) {
    throw "Did not find files:`n$($notFound -join "`n")"
}
else {
    "Found all files!"
}

# build psgallery module
$psGalleryDir = "$PSScriptRoot/../tmp/PSGallery/Pester/"
if (Test-Path $psGalleryDir) {
    Remove-Item -Recurse -Force $psGalleryDir
}
$null = New-Item -ItemType Directory -Path $psGalleryDir
Copy-Item "$PSScriptRoot/../bin/*" $psGalleryDir -Recurse


# build nuget for nuget.org and chocolatey
$nugetDir = "$PSScriptRoot/../tmp/nuget/"
if (Test-Path $nugetDir) {
    Remove-Item -Recurse -Force $nugetDir
}
$null = New-Item -ItemType Directory -Path $nugetDir
Copy-Item "$PSScriptRoot/../bin/*" $nugetDir -Recurse

Out-File $nugetDir\VERIFICATION.txt -InputObject @"
VERIFICATION
Verification is intended to assist the Chocolatey moderators and community
in verifying that this package's contents are trustworthy.

You can use one of the following methods to obtain the checksum
  - Use powershell function 'Get-Filehash'
  - Use chocolatey utility 'checksum.exe'

CHECKSUMS
"@

Get-ChildItem -Path $bin -Filter *.dll -Recurse | Foreach-Object {
    $path = $_.FullName
    $relativePath = ($path -replace [regex]::Escape($nugetDir.TrimEnd('/').TrimEnd('\'))).TrimStart('/').TrimStart('\')
    $hash = Get-FileHash  -Path $path -Algorithm SHA256 | Select-Object -ExpandProperty Hash
    Out-File $nugetDir\VERIFICATION.txt -Append -InputObject @"
    file: $relativePath
    hash: $hash
    algorithm: sha256
"@
}

& nuget pack "$PSScriptRoot/Pester.nuspec" -OutputDirectory $nugetDir -NoPackageAnalysis -version $version
$nupkg = (Join-Path $nugetDir "Pester.$version.nupkg")
& nuget sign $nupkg -CertificateFingerprint $CertificateThumbprint -Timestamper "http://timestamp.digicert.com"

Publish-Module -Path $psGalleryDir -NuGetApiKey $PsGalleryApiKey -Verbose -Force

if (-not $isPreRelease -or $Force) {
    & nuget push $nupkg -Source https://api.nuget.org/v3/index.json -apikey $NugetApiKey
    & nuget push $nupkg -Source https://push.chocolatey.org/ -apikey $ChocolateyApiKey

    if ([string]::IsNullOrWhiteSpace($GitHubUsername) -or [string]::IsNullOrWhiteSpace($GitHubToken)) {
        Write-Host "Missing GitHub credentials, not triggering a Pester documentation update for $version"
    } else {
        $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($GitHubUsername):$($GitHubToken)"))
        $Headers = @{
            'Accept' = 'application/vnd.github.v3+json'
            'Authorization' = "Basic $encodedCreds"
        }
        $Body = @{
            'ref' = 'master'
            'inputs' = @{
                'pester-version' = $Version
            }
        }
        # There can be caching issues between the time a packaged is pushed to the PS Gallery, and when it becomes searchable. Hopefully waiting one
        # minute gives the Gallery enough time to process the new package and make it available
        Start-Sleep -Seconds 60
        # See https://docs.github.com/rest/reference/actions#create-a-workflow-dispatch-event for more information
        Invoke-WebRequest -Uri 'https://api.github.com/repos/pester/docs/actions/workflows/update-from-pester.yml/dispatches' -Method POST -Headers $Headers -Body (ConvertTo-JSON -InputObject $Body)
    }
}
else {
    Write-Host "This is pre-release $version, not pushing to Nuget and Chocolatey."
}
