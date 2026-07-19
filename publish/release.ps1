# build should provide '%system.teamcity.build.checkoutDir%'
param (
    [Parameter(Mandatory)]
    [String] $PsGalleryApiKey,
    [String] $NugetApiKey,
    [String] $ChocolateyApiKey,
    [String] $TenantId,
    [String] $VaultUrl,
    [String] $CertificateName,
    [Switch] $Force,
    [Switch] $SkipTests
)

$ErrorActionPreference = 'Stop'

$bin = "$PSScriptRoot/../bin"

# checking the path first because I want to fail the script when I fail to remove all files
if (Test-Path $bin) {
    Remove-Item $bin -Recurse -Force
}

pwsh -noprofile -c "$PSScriptRoot/../build.ps1 -Clean -Inline"
if ($LASTEXITCODE -ne 0) {
    throw "build failed!"
}

$m = Test-ModuleManifest $bin/Pester.psd1
$version = if ($m.PrivateData -and $m.PrivateData.PSData -and $m.PrivateData.PSData.PreRelease) {
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

if ($SkipTests) {
    Write-Host "Skipping tests because -SkipTests was specified."
}
else {
    pwsh -noprofile -c "$PSSCriptRoot/../test.ps1 -nobuild"
    if ($LASTEXITCODE -ne 0) {
        throw "test failed!"
    }
}

pwsh -noprofile -c "$PSScriptRoot/../build.ps1 -Inline"
if ((Get-Item $bin/Pester.psm1).Length -lt 50KB) {
    throw "Module is too small, are you publishing non-inlined module?"
}

& "$PSScriptRoot/signModule.ps1" -VaultUrl $VaultUrl -TenantId $TenantId -CertificateName $CertificateName -Path $bin

$files = . "$PSScriptRoot/filesToPublish.ps1"

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
    'Found all files!'
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
Copy-Item "$PSScriptRoot/../LICENSE" $nugetDir -Recurse

Out-File "$nugetDir/VERIFICATION.txt" -InputObject @'
VERIFICATION
Verification is intended to assist the Chocolatey moderators and community
in verifying that this package's contents are trustworthy.

You can use one of the following methods to obtain the checksum
  - Use powershell function 'Get-Filehash'
  - Use chocolatey utility 'checksum.exe'

CHECKSUMS
'@

Get-ChildItem -Path $bin -Filter *.dll -Recurse | ForEach-Object {
    $path = $_.FullName
    $relativePath = ($path -replace [regex]::Escape($nugetDir.TrimEnd('/').TrimEnd('\'))).TrimStart('/').TrimStart('\')
    $hash = Get-FileHash -Path $path -Algorithm SHA256 | Select-Object -ExpandProperty Hash
    Out-File "$nugetDir/VERIFICATION.txt" -Append -InputObject @"
    file: $relativePath
    hash: $hash
    algorithm: sha256
"@
}

# The packaged .nupkg goes to NuGet.org and Chocolatey. Pack it into its own folder named for
# the publish target, so when a push fails the exact package can be grabbed from the build
# artifact and pushed by hand. The pack input stays tmp/nuget (the nuspec globs it), only the
# output nupkg goes here.
$nugetOrgDir = "$PSScriptRoot/../tmp/nuget.org/"
if (Test-Path $nugetOrgDir) {
    Remove-Item -Recurse -Force $nugetOrgDir
}
$null = New-Item -ItemType Directory -Path $nugetOrgDir

& nuget pack "$PSScriptRoot/Pester.nuspec" -OutputDirectory $nugetOrgDir -NoPackageAnalysis -version $version
[string] $nupkg = (Join-Path $nugetOrgDir "Pester.$version.nupkg")

dotnet tool install --global NuGetKeyVaultSignTool
if (0 -ne $LASTEXITCODE) {
    throw "Failed to install NuGetKeyVaultSignTool"
}

Write-Host "Nuget path: $nupkg"
NuGetKeyVaultSignTool sign -kvu $VaultUrl -kvm -kvc $CertificateName -kvt $TenantId -own "nohwnd,fflaten" -tr "http://timestamp.digicert.com" $nupkg
if (0 -ne $LASTEXITCODE) {
    throw "Failed to sign nupkg"
}

NuGetKeyVaultSignTool verify $nupkg
if (0 -ne $LASTEXITCODE) {
    throw "Failed to verify nupkg"
}

# NuGet.org and Chocolatey get the identical signed package. Copy it into the chocolatey
# folder so each target's published .nupkg sits in its own folder in the build artifact.
$chocolateyDir = "$PSScriptRoot/../tmp/chocolatey/"
if (Test-Path $chocolateyDir) {
    Remove-Item -Recurse -Force $chocolateyDir
}
$null = New-Item -ItemType Directory -Path $chocolateyDir
[string] $chocolateyNupkg = (Join-Path $chocolateyDir "Pester.$version.nupkg")
Copy-Item $nupkg $chocolateyNupkg

# Publish to every feed, and keep going even if one fails, so a single broken feed does not
# block the others. Collect the failures and fail the build at the end. The built packages are
# in tmp/ (kept as a pipeline artifact), so any failed feed can be grabbed from the artifact and
# published by hand.
$failedFeeds = @()

# The PowerShell Gallery is published from the module folder ($psGalleryDir = tmp/PSGallery/Pester),
# not from a .nupkg, so that folder is the gallery's build artifact.
try {
    Publish-Module -Path $psGalleryDir -NuGetApiKey $PsGalleryApiKey -Verbose -Force
}
catch {
    Write-Warning "Failed to publish to PowerShell Gallery: $_"
    $failedFeeds += 'PowerShell Gallery'
}

if (-not $isPreRelease -or $Force) {
    try {
        & nuget push $nupkg -Source https://api.nuget.org/v3/index.json -apikey $NugetApiKey
        if (0 -ne $LASTEXITCODE) { throw "nuget push exited with code $LASTEXITCODE" }
    }
    catch {
        Write-Warning "Failed to push to NuGet.org: $_"
        $failedFeeds += 'NuGet.org'
    }

    try {
        & nuget push $chocolateyNupkg -Source https://push.chocolatey.org/ -apikey $ChocolateyApiKey
        if (0 -ne $LASTEXITCODE) { throw "nuget push exited with code $LASTEXITCODE" }
    }
    catch {
        Write-Warning "Failed to push to Chocolatey: $_"
        $failedFeeds += 'Chocolatey'
    }
}
else {
    Write-Host "This is pre-release $version, not pushing to Nuget and Chocolatey."
}

if (0 -lt $failedFeeds.Count) {
    throw "Failed to publish to: $($failedFeeds -join ', '). Grab the built packages from the tmp/ pipeline artifact and publish them by hand."
}
