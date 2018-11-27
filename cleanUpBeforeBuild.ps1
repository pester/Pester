# cleaning up remains of previous builds 
# examples and all test files 
# in the next step we sign all scripts so
# we want to reduce how many files will be signed
#
# this clean up is not removing all unneeded files,
# it only removes the main parts
# each package then decides what will be part of it

$buildDir = "$PSScriptRoot\build"
if (Test-Path $buildDir) {
    Write-Verbose "Removing build dir"
    Remove-Item $buildDir -Recurse -Force -Confirm:$false -Verbose
}

Write-Verbose "Removing all examples"
Remove-Item "$PSScriptRoot\Examples" -Recurse -Force -Confirm:$false -Verbose
Write-Verbose "Removing docs"
Remove-Item "$PSScriptRoot\doc" -Recurse -Force -Confirm:$false -Verbose

Write-Verbose "Removing all Test Files"
Get-ChildItem $PSScriptRoot -Recurse -Filter *.Tests.ps1 | Remove-Item -Force -Verbose