$pwd = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$pwd\$sut"
. "$pwd\..\Pester.ps1"

Describe "In" {
    Setup -Dir "test_path"

    It "executes a command in that directory" {
        In "$TestDrive" -Execute { "" | Out-File "test_file" }
        "$TestDrive\test_file".should.exist() 
    }
}
