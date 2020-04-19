$VerbosePreference = 'Continue'
$ErrorActionPreference = 'Stop'

try {
    $baseDir = $PSScriptRoot
    $buildDir = "$baseDir\build\nuget"
    $nugetExe = "$baseDir\vendor\tools\nuget.exe"
    $targetBase = "tools"

    Write-Verbose "Running in $baseDir"
    Write-Verbose "Building to $buildDir"

    $version = git.exe describe --abbrev=0 --tags
    Write-Verbose "Version $version"

    Write-Verbose "Creating $buildDir"
    mkdir $buildDir
    Write-Verbose "Building package"
    &$nugetExe pack "$baseDir\Pester.nuspec" -OutputDirectory $buildDir -NoPackageAnalysis -version $version -Properties targetBase=$targetBase
}
catch {
    Write-Error -ErrorRecord $_
    exit 1
}
