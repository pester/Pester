# cleaning up remains of previous builds
# examples and all test files
# in the next step we sign all scripts so
# we want to reduce how many files will be signed
#
# this clean up is not removing all unneeded files,
# it only removes the main parts
# each package then decides what will be part of it

$buildDir = "$PSScriptRoot\build"
$ErrorActionPreference = 'Stop'

if (Test-Path $buildDir) {
    Write-Verbose "Removing build dir"
    Remove-Item $buildDir -Recurse -Force -Confirm:$false -Verbose -ErrorAction 'Stop'
}

if (Test-Path "$PSScriptRoot\Examples") {
    Write-Verbose "Removing all examples"
    Remove-Item "$PSScriptRoot\Examples" -Recurse -Force -Confirm:$false -Verbose -ErrorAction 'Stop'
}

if (Test-Path "$PSScriptRoot\images") {
    Write-Verbose "Removing images"
    Remove-Item "$PSScriptRoot\images" -Recurse -Force -Confirm:$false -Verbose -ErrorAction 'Stop'
}

Write-Verbose "Removing all Test Files"
Get-ChildItem $PSScriptRoot -Recurse -Filter *.Tests.ps1 | Remove-Item -Force -Verbose -ErrorAction 'Stop'
