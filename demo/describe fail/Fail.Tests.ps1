Describe "d1" {

    BeforeAll {
        throw "OMG!"
    }

    It "i1" {
        $true | Should -Be $true
    }

    It "i2" -TestCases @(
        @{ Value = 1 }
        @{ Value = 2 }
    ) {
        $true | Should -Be $true
    }
}
