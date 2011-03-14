param($version = "0.0.0")

$rootDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$nuspec = (Resolve-Path *.nuspec)
$buildDir = "$rootDir\build"
$packageDir = "$buildDir\package"

$nuget = "$rootDir\tools\nuget.exe" 

function Cleanup() {
   if (Test-Path $buildDir) {
        Remove-Item $buildDir -Recurse -Force
   }
}

function ArrangeFiles() {
    Copy-Item -Recurse .\Functions $packageDir\tools\Functions
    Copy-Item -Recurse .\ObjectAdaptations $packageDir\tools\ObjectAdaptations
    Copy-Item -Recurse .\Examples $packageDir\tools\Examples
    Copy-Item *.ps1 $packageDir\tools\
}

function CreatePackage() {
    & $nuget pack $nuspec -BasePath $packageDir -Version $version -OutputDirectory $buildDir
}

Cleanup
ArrangeFiles
CreatePackage
