Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterBe" {
        It "returns true if the 2 arguments are equal" {
            Test-PositiveAssertion (PesterBe 1 1)
        }

        It "returns true if the 2 arguments are equal and have different case" {
            Test-PositiveAssertion (PesterBe "A" "a")
        }

        It "returns false if the 2 arguments are not equal" {
            Test-NegativeAssertion (PesterBe 1 2)
        }

        It 'Compares Arrays properly' {
            $array = @(1,2,3,4,'I am a string', (New-Object psobject -Property @{ IAm = 'An Object' }))
            $array | Should Be $array
        }

        It 'Compares arrays with correct case-insensitive behavior' {
            $string = 'I am a string'
            $array = @(1,2,3,4,$string)
            $arrayWithCaps = @(1,2,3,4,$string.ToUpper())

            $array | Should Be $arrayWithCaps
        }
    }

    Describe "BeExactly" {
        It "passes if letter case matches" {
            'a' | Should BeExactly 'a'
        }

        It "fails if letter case doesn't match" {
            'A' | Should Not BeExactly 'a'
        }

        It "passes for numbers" {
            1 | Should BeExactly 1
            2.15 | Should BeExactly 2.15
        }

        It 'Compares Arrays properly' {
            $array = @(1,2,3,4,'I am a string', (New-Object psobject -Property @{ IAm = 'An Object' }))
            $array | Should BeExactly $array
        }

        It 'Compares arrays with correct case-sensitive behavior' {
            $string = 'I am a string'
            $array = @(1,2,3,4,$string)
            $arrayWithCaps = @(1,2,3,4,$string.ToUpper())

            $array | Should Not BeExactly $arrayWithCaps
        }
    }
}
