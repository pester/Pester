$VerbosePreference = 'Continue'
$ErrorActionPreference = 'Stop'
$baseDir = $PSScriptRoot

try
{
    $buildDir = "$baseDir\build\psgallery\Pester"
    if (Test-Path $buildDir) {
        Write-Verbose 'Removing build folder'
        Remove-Item -LiteralPath $buildDir -Recurse -Force -Confirm:$false -Verbose
    }

    $null = New-Item -Path $buildDir -ItemType Directory -Verbose

    Write-Verbose "Copying release files to build folder '$buildDir'"
    Copy-Item $baseDir\Pester.ps?1          $buildDir\
    Copy-Item $baseDir\LICENSE              $buildDir\
    Copy-Item $baseDir\nunit_schema_2.5.xsd $buildDir\
    Copy-Item $baseDir\bin                  $buildDir\ -Recurse -Exclude *.tests.ps1
    Copy-Item $baseDir\Functions            $buildDir\ -Recurse -Exclude *.tests.ps1
    Copy-Item $baseDir\Dependencies         $buildDir\ -Recurse -Exclude *.tests.ps1
    Copy-Item $baseDir\Snippets             $buildDir\ -Recurse -Exclude *.tests.ps1
    Copy-Item $baseDir\en-US                $buildDir\ -Recurse -Exclude *.tests.ps1
    Copy-Item $baseDir\lib                  $buildDir\ -Recurse -Exclude *.tests.ps1

    Write-Verbose 'Copy complete. Contents:'
    Get-ChildItem $buildDir -Recurse | Out-Host
}
catch
{
    Write-Error -ErrorRecord $_
    exit 1
}
