$psake.use_exit_on_error = $true
properties {
    $currentDir = resolve-path .
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    $baseDir = Split-Path -parent $Invocation.MyCommand.Definition | split-path -parent | split-path -parent | split-path -parent | split-path -parent
    echo $baseDir
    $version = git describe --abbrev=0 --tags
    $version = $version + '.' + (git log $($version + '..') --pretty=oneline | measure-object).Count
    $nugetDir = "$baseDir\.NuGet"
}

Task default -depends Test, Package

Task Test {
    CD "$baseDir"
    ."$baseDir\bin\Pester.bat"
    CD $currentDir
}
Task Version-Module{
    $v = git describe --abbrev=0 --tags
    $changeset=(git log -1 $($v + '..') --pretty=format:%H)
    (Get-Content "$baseDir\Pester.psm1") | % {$_ -replace "# Version: [0-9]+(\.([0-9]+|\*)){1,3}", "# Version: $version" } | % {$_ -replace "# Changeset: ([a-f0-9]{40})?", "# Changeset: $changeset" } | Set-Content "$baseDir\Pester.psm1"
}

Task Package -depends Version-Module {
    if (Test-Path "$baseDir\build") {
      Remove-Item "$baseDir\build" -Recurse -Force
    }

    mkdir "$baseDir\build"
    exec { ."$baseDir\vendor\tools\nuget" pack "$baseDir\Pester.nuspec" -OutputDirectory "$baseDir\build" -NoPackageAnalysis -version $version }
}
