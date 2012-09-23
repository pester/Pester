$psake.use_exit_on_error = $true
properties {
    $currentDir = resolve-path .
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    $baseDir = Split-Path -parent $Invocation.MyCommand.Definition | split-path -parent | split-path -parent | split-path -parent | split-path -parent
    echo $baseDir
    $version = git describe --abbrev=0 --tags
    $version = $version.substring(1) + '.' + (git log $($version + '..') --pretty=oneline | measure-object).Count
    $nugetDir = "$baseDir\.NuGet"
}

Task default -depends Test, Package

Task Test {
    CD "$baseDir"
    ."$baseDir\bin\Pester.bat"
    CD $currentDir
}

Task Package {
    if (Test-Path "$baseDir\build") {
      Remove-Item "$baseDir\build" -Recurse -Force
    }

    mkdir "$baseDir\build"
    ."$baseDir\vendor\tools\nuget" pack "$baseDir\Pester.nuspec" -OutputDirectory "$baseDir\build" -NoPackageAnalysis
}
