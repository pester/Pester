$psake.use_exit_on_error = $true
properties {
    $currentDir = resolve-path .
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    $baseDir = $psake.build_script_dir
    $version = git describe --abbrev=0 --tags
    $nugetExe = "$baseDir\vendor\tools\nuget"
}

Task default -depends Test, Build
Task Build -depends Package
Task Package -depends Version-Module, Pack-Nuget, Unversion-Module
Task Release -depends Build, Push-Nuget

Task Test {
    CD "$baseDir"
    exec {."$baseDir\bin\Pester.bat"}
    CD $currentDir
}

Task Version-Module{
    $v = git describe --abbrev=0 --tags
    $changeset=(git log -1 $($v + '..') --pretty=format:%H)
    (Get-Content "$baseDir\Pester.psm1") `
      | % {$_ -replace "\`$version\`$", "$version" } `
      | % {$_ -replace "\`$sha\`$", "$changeset" } `
      | Set-Content "$baseDir\Pester.psm1"
}

Task Unversion-Module{
    git checkout -- .\Pester.psm1
}

Task Pack-Nuget {
    if (Test-Path "$baseDir\build") {
      Remove-Item "$baseDir\build" -Recurse -Force
    }

    mkdir "$baseDir\build"
    exec {
      . $nugetExe pack "$baseDir\Pester.nuspec" -OutputDirectory "$baseDir\build" `
      -NoPackageAnalysis -version $version
    }
}

Task Push-Nuget {
    $pkg = Get-Item -path $baseDir\build\Pester.1.*.*.nupkg
    exec { .$nugetExe push $pkg.FullName }
}

