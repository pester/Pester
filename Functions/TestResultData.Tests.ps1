$pwd = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$pwd\..\Pester.ps1"

Describe "Test-Report" {

    It "keeps a record of all the fixture descriptions" {
        $sut = Create-TestResultData 

        $sut.AddDescription("Description")

        $sut.GetDescriptions().should.be("Description")
    }

    It "Keeps a record of multiple fixture descriptions" {
        $sut = Create-TestResultData

        $sut.AddDescription("Description1")
        $sut.AddDescription("Description2")

        $sut.GetDescriptions().should.have_count_of(2)
    }
    
}

