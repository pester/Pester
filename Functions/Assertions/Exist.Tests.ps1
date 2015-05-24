Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "PesterExist" {
        It "returns true for paths that exist" {
            Test-PositiveAssertion (PesterExist $TestDrive)
        }

        It "returns false for paths do not exist" {
            Test-NegativeAssertion (PesterExist "$TestDrive\nonexistant")
        }

        It 'works for path with escaped [ ] characters' {
            New-Item -Path "TestDrive:\[test].txt" -ItemType File | Out-Null
            "TestDrive:\``[test``].txt"  | Should Exist
        }

        It 'returns correct result for function drive' {
            function f1 {}

            'function:f1' | Should Exist
        }

        It 'returns correct result for env drive' {
            $env:test = 'somevalue'

            'env:test' | Should Exist
        }

        It 'returns correct result for env drive' {
            $env:test = 'somevalue'

            'env:test' | Should Exist
        }
    }
}
