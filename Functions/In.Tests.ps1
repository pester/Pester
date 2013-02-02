$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe "the In statement" {
    Setup -Dir "test_path"

    It "executes a command in that directory" {
        In "$TestDrive" -Execute { "" | Out-File "test_file" }
        "$TestDrive\test_file" | Should Exist
    }

    It "updates the `$pwd variable when executed" {
        In "$TestDrive\test_path" -Execute { $env:Pester_Test=$pwd }
        $env:Pester_Test | Should Match "test_path"
        $env:Pester_Test=""
    }
}

