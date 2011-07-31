$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe "the In statement" {
    Setup -Dir "test_path"

    It "executes a command in that directory" {
        In "$TestDrive" -Execute { "" | Out-File "test_file" }
        "$TestDrive\test_file".should.exist() 
    }

    It "updates the `$pwd variable when executed" {
        In "$TestDrive\test_path" -Execute { Write-Host $pwd }
        $(Get-ConsoleText).should.match("test_path")
    }

    It "will still allow the It {} block to transcribe the console" {
        In "$TestDrive" -Execute { Write-Host "The bird is the word" }
        $(Get-ConsoleText).should.match("The bird is the word")
    }
}
