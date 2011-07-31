
function Invoke-Pester($relative_path = ".") {

    . "$PSScriptRoot\ObjectAdaptations\PesterFailure.ps1"

    Update-TypeData -pre "$PSScriptRoot\ObjectAdaptations\types.ps1xml" -ErrorAction SilentlyContinue

    . "$PSScriptRoot\Functions\TestResults.ps1"

    $fixtures_path = Resolve-Path $relative_path
    Write-Host Executing all tests in $fixtures_path

    Get-ChildItem $fixtures_path -Recurse |
        ? { $_.Name -match "\.Tests\." } |
        % { & $_.PSPath }

    Write-TestReport
    Exit-WithCode
}

function Write-UsageForCreateFixture {
    "invalid usage, please specify (path, name)" | Write-Host
    "eg: .\Create-Fixture -Path Foo -Name Bar" | Write-Host
    "creates .\Foo\Bar.ps1 and .\Foo.Bar.Tests.ps1" | Write-Host
}

function Create-File($file_path, $contents = "") {

    if (-not (Test-Path $file_path)) {
        $contents | Out-File $file_path -Encoding ASCII
        "Creating" | Write-Host -Fore Green -NoNewLine
    } else {
        "Skipping" | Write-Host -Fore Yellow -NoNewLine
    }
    " => $file_path" | Write-Host
}

function Create-Fixture($path, $name) {

    if ([String]::IsNullOrEmpty($path) -or [String]::IsNullOrEmpty($name)) {
        Write-UsageForCreateFixture
        return
    }

    # TODO clean up $path cleanup
    $path = $path.TrimStart(".")
    $path = $path.TrimStart("\")

    . "$PSScriptRoot\Functions\Get-RelativePath"

    $pester_path = gci -Recurse -Include Pester.ps1
    $rel_path_to_pester = Get-RelativePath "$pwd\$path" $pester_path 

    if (-not (Test-Path $path)) {
        & md $path | Out-Null
    }

    $test_code = "function $name {

    }"

    $fixture_code = "`$here = Split-Path -Parent `$MyInvocation.MyCommand.Path
    `$sut = (Split-Path -Leaf `$MyInvocation.MyCommand.Path).Replace(`".Tests.`", `".`")
    . `"`$here\`$sut`"
    . `"`$here\$rel_path_to_pester`"

    Describe `"$name`" {

        It `"does something useful`" {
            `$true.should.be(`$false)
        }
    }"

    Create-File "$path\$name.ps1" $test_code
    Create-File "$path\$name.Tests.ps1" $fixture_code
}

Export-ModuleMember Invoke-Pester, Create-Fixture
