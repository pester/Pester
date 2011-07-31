$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe "the It {} block" {

    It "records a transcript of the console output" {
        Write-Host "Hibbily Jibbily"
        $(Get-ConsoleText).should.match("Hibbily Jibbily")
    }
}
