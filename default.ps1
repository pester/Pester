$psake.use_exit_on_error = $true
properties {
    $currentDir = resolve-path .
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    $baseDir = $psake.build_script_dir
    echo $baseDir
    $version = git describe --abbrev=0 --tags
    $buildNumber = '-alpha-' + (git log $($version + '..') --pretty=oneline | measure-object).Count
    $nugetExe = "$baseDir\vendor\tools\nuget"
}

Task default -depends Build
Task Build -depends Test, Package
Task Package -depends Version-Module, Pack-Nuget, Unversion-Module
Task Release -depends Strip-BuildNumber, Build, Push-Nuget

Task Test {
    "$baseDir\bin\Pester.bat"
}

Task Strip-BuildNumber {
    $buildNumber = ""
}

Task Version-Module{
    $v = git describe --abbrev=0 --tags
    $changeset=(git log -1 $($v + '..') --pretty=format:%H)
    (Get-Content "$baseDir\Pester.psm1") | % {$_ -replace "\`$version\`$", "$version$buildNumber" } | % {$_ -replace "\`$sha\`$", "$changeset" } | Set-Content "$baseDir\Pester.psm1"
}

Task Unversion-Module{
    $v = git describe --abbrev=0 --tags
    $changeset=(git log -1 $($v + '..') --pretty=format:%H)
    (Get-Content "$baseDir\Pester.psm1") | % {$_ -replace "$version$buildNumber", "`$version`$" } | % {$_ -replace "$changeset", "`$sha`$" } | Set-Content "$baseDir\Pester.psm1"
}

Task Pack-Nuget {
    if (Test-Path "$baseDir\build") {
      Remove-Item "$baseDir\build" -Recurse -Force
    }

    mkdir "$baseDir\build"
    exec { .$nugetExe pack "$baseDir\Pester.nuspec" -OutputDirectory "$baseDir\build" -NoPackageAnalysis -version $version$buildNumber }
}

Task Push-Nuget {
    $pkg = Get-Item -path $baseDir\build\Pester.1.*.*.nupkg
    exec { .$nugetExe push $pkg.FullName }
}