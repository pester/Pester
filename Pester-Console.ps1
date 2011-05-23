param($relative_path = ".")

$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$script_dir\ObjectAdaptations\PesterFailure.ps1"

Update-TypeData -pre "$script_dir\ObjectAdaptations\types.ps1xml" -ErrorAction SilentlyContinue

. "$script_dir\Functions\TestResults.ps1"

$fixtures_path = Resolve-Path $relative_path
Write-Host Executing all tests in $fixtures_path

Get-ChildItem $fixtures_path -Recurse |
    ? { $_.Name -match "\.Tests\." } |
    % { & $_.PSPath }

Write-TestReport
Exit-WithCode
