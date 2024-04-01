Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Get-CustomFailureMessage" {
        It "returns correct custom message when no tokens are provided" {
            $expected = "Static failure message."
            $customMessage = "Static failure message."
            Get-CustomFailureMessage -CustomMessage $customMessage -Expected 1 -Actual 2 | Verify-Equal $expected
        }

        It "returns correct custom message when positional tokens are provided" {
            $expected = "We expected string to be 1, because that is the default value, but got 2."
            $customMessage = "We expected string to be {0}, because that is the default value, but got {1}."
            Get-CustomFailureMessage -CustomMessage $customMessage -Expected 1 -Actual 2 | Verify-Equal $expected
        }

        It "returns correct custom message when named tokens are provided" {
            $expected = "We expected string to be 1, because that is the default value, but got 2."
            $customMessage = "We expected string to be <expected>, because that is the default value, but got <actual>."
            Get-CustomFailureMessage -CustomMessage $customMessage -Expected 1 -Actual 2 | Verify-Equal $expected
        }

        It "returns correct custom message when shortened named tokens are provided" {
            $expected = "We expected string to be 1, because that is the default value, but got 2."
            $customMessage = "We expected string to be <e>, because that is the default value, but got <a>."
            Get-CustomFailureMessage -CustomMessage $customMessage -Expected 1 -Actual 2 | Verify-Equal $expected
        }
    }
}
