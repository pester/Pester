param($path, $name)

$script:dir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$($script:dir)\Functions\Get-RelativePath"

$pester_path = gci -Recurse -Include Pester.ps1
$rel_path_to_pester = Get-RelativePath "$pwd\$path" $pester_path 

if (-not (Test-Path $path)) {
    & md $path | Out-Null
}

$template = "`$pwd = Split-Path -Parent `$MyInvocation.MyCommand.Path
. `"`$pwd\$name.ps1`"
. `"`$pwd\$rel_path_to_pester`"

Describe `"$name`" {

    It `"does something useful`" {
        `$true.should.be(`$false)
    }
}"

$code_file = "$path\$name.ps1"
$test_file = "$path\$name.Tests.ps1"

"" | Out-File $code_file
$template | Out-File $test_file
Write-Host $template
