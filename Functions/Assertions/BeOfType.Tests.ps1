Set-StrictMode -Version Latest

InModuleScope Pester {
    Describe "Should -BeOfType" {
        It "passes if value is of the expected type" {
            1 | Should BeOfType Int
            2.0 | Should BeOfType ([double])
            1 | Should -BeOfType Int
            2.0 | Should -BeOfType ([double])
        }

        It "fails if value is of a different types" {
            2 | Should Not BeOfType double
            2.0 | Should Not BeOfType ([string])
            2 | Should -Not -BeOfType double
            2.0 | Should -Not -BeOfType ([string])
        }

        It "throws argument execption if type isn't a loaded type" {
            $err = { 5 | Should -Not -BeOfType 'UnknownType' } | Verify-Throw
            $err.Exception | Verify-Type ([ArgumentException])
        }

        It "throws argument execption if type isn't a loaded type" {
            $err = { 5 | Should -BeOfType 'UnknownType' } | Verify-Throw
            $err.Exception | Verify-Type ([ArgumentException])
        }

        It "returns the correct assertion message when actual value has a real type" {
            $err = { 'ab' | Should -BeOfType ([int]) -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected the value to have type [int] or any of its subtypes, because reason, but got 'ab' with type [string]."
        }

        It "returns the correct assertion message when actual value is `$null" {
            $err = { $null | Should -BeOfType ([int]) -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected the value to have type [int] or any of its subtypes, because reason, but got $null with type $null.'
        }
    }

    Describe "Should -Not -BeOfType" {
        It "throws argument execption if type isn't a loaded type" {
            $err = { 5 | Should -Not -BeOfType 'UnknownType' } | Verify-Throw
            $err.Exception | Verify-Type ([ArgumentException])
        }

        It "returns the correct assertion message when actual value has a real type" {
            $err = { 1 | Should -Not -BeOfType ([int]) -Because 'reason' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal 'Expected the value to not have type [int] or any of its subtypes, because reason, but got 1 with type [int].'
        }
    }
}
