Set-StrictMode -Version Latest

Describe "describe state tests" {
    It "passing" {
        1 | Should -Be 1
    }

    It "fails" {
        1 | Should -Be 2
    }

    It "passing with testcases" -TestCases @(
        @{ Value = 1 }
        @{ Value = 2 }
    ) {
        1 | Should -Be 1
    }
}
