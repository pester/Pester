. $PSScriptRoot\Get-Pokemon.ps1

Describe "Get pikachu by Get-Pokemon from the real api" {

    $pikachu = Get-Pokemon -Name pikachu

    It "has correct Name" -Tag IntegrationTest {
        $pikachu.Name | Should -Be "pikachu"
    }

    It "has correct Type" -Tag IntegrationTest {
        $pikachu.Type | Should -Be "electric"
    }

    It "has correct Weight" -Tag IntegrationTest {
        $pikachu.Weight | Should -Be 60
    }

    It "has correct Height" -Tag IntegrationTest {
        $pikachu.Height | Should -Be 4
    }
}