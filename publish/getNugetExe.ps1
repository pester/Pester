$VerbosePreference = 'Continue'
$ErrorActionPreference = 'Stop'

try {
    # had problems running nuget.exe on the build server
    # so I try to run it first and if that does not work
    # I download a version from the web and try that

    $nugetPath = "$psScriptRoot\vendor\tools\nuget.exe"
    Write-Output "Nuget path ${nugetPath}"

    $nugetFound = Test-Path $nugetPath
    if ($nugetFound) {
        Write-Output "Found local nuget.exe running it"
        $nugetRunnable = $false
        try {
            &$nugetPath | Select-Object -First 1
            $nugetRunnable = $true
        }
        catch {
            Write-Output 'Could not run local nuget.exe. Failed with ("$_")'
            Remove-Item $nugetPath -Force -Confirm:$false -Verbose
        }
    }
    else {
        Write-Output "Local nuget.exe not found"
    }

    if (-not $nugetFound -or -not $nugetRunnable) {
        $vendorDirectory = $nugetPath | Split-Path
        if (-not(Test-Path $VendorDirectory)) {
            mkdir $vendorDirectory
        }

        Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/v4.4.1/nuget.exe" -OutFile $nugetPath -Verbose
        "Downloaded $(&$nugetPath | Select-Object -First 1)"
    }

}
catch {
    Write-Error -ErrorRecord $_
    exit 1
}
