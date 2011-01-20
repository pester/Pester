$pwd = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$pwd\..\Pester.ps1"

Describe "Test-Report" {

    It "keeps a record of all the fixture descriptions" {
        $sut = Create-TestResultData 

        $sut.AddDescription("Description")

        $sut.GetDescriptions().should.be("Description")
    }
}

