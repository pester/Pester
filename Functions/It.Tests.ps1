$pwd = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$pwd\$sut"
. "$pwd\..\Pester.ps1"

Describe "the It {} block" {

    It "records a transcript of the console output" {
        Write-Host "Hibbily Jibbily"
        $(Get-ConsoleText).should.match("Hibbily Jibbily")
    }
}
