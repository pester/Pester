$VerbosePreference = 'Continue'
$ErrorActionPreference = 'Stop'

try
{
    $baseDir = $PSScriptRoot
    $buildDir = "$baseDir\build\nuget"
    $nugetExe = "$baseDir\vendor\tools\nuget.exe"
    $targetBase = "tools"

    Write-Verbose "Running in $baseDir"
    Write-Verbose "Building to $buildDir"

    $version = git.exe describe --abbrev=0 --tags
    Write-Verbose "Version $version"

    if (Test-Path $buildDir) {
        Write-Verbose "Removing build dir"
        Remove-Item $buildDir -Recurse -Force -Confirm:$false -Verbose
    }

    Write-Verbose "Removing all Test Files"
    Get-ChildItem $baseDir -Recurse -Filter *.Tests.ps1 | Remove-Item -Force -Verbose

    Write-Verbose "Creating $buildDir"
    mkdir $buildDir
    Write-Verbose "Building package"
    &$nugetExe pack "$baseDir\Pester.nuspec" -OutputDirectory $buildDir -NoPackageAnalysis -version $version -Properties targetBase=$targetBase
}
catch
{
    Write-Error -ErrorRecord $_
    exit 1
}
