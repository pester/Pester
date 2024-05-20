Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Get-AssertionMessage" {
        It "returns correct message when no tokens are provided" {
            $expected = "Static failure message."
            $customMessage = "Static failure message."
            Get-AssertionMessage -CustomMessage $customMessage -Expected 1 -Actual 2 | Verify-Equal $expected
        }

        It "returns correct message when named tokens are provided" {
            $expected = "We expected string to be 1, but got 2."
            $customMessage = "We expected string to be <expected>, but got <actual>."
            Get-AssertionMessage -CustomMessage $customMessage -Expected 1 -Actual 2 | Verify-Equal $expected
        }

        It "returns correct message when complex objects are provided" {
            $expected = "We expected string to be PSObject{Age=28; Name='Jakub'}, but got 2."
            $customMessage = "We expected string to be <expected>, but got <actual>."
            Get-AssertionMessage -CustomMessage $customMessage -Expected ([PSCustomObject]@{Name = 'Jakub'; Age = 28 }) -Actual 2 | Verify-Equal $expected
        }

        It "returns correct message when type tokens are provided" {
            $expected = "We expected string to be [PSObject], but got [int]."
            $customMessage = "We expected string to be <expectedType>, but got <actualType>."
            Get-AssertionMessage -CustomMessage $customMessage -Expected ([PSCustomObject]@{Name = 'Jakub'; Age = 28 }) -Actual 2 | Verify-Equal $expected
        }

        It "returns correct type message when `$null is provided" {
            $expected = "Expected type is [null], and actual type is [null]."
            $customMessage = "Expected type is <expectedType>, and actual type is <actualType>."
            Get-AssertionMessage -CustomMessage $customMessage -Expected $null -Actual $null | Verify-Equal $expected
        }

        It "returns correct message when option is provided" {
            $expected = "Expected 'a', but got 'b'. Used options: CaseSensitive, IgnoreWhitespace."
            $customMessage = "Expected 'a', but got 'b'. <options>"
            Get-AssertionMessage -CustomMessage $customMessage -Expected 'a' -Actual 'b' -Option "CaseSensitive", "IgnoreWhitespace" | Verify-Equal $expected
        }

        It "returns correct message when additional data are provided" {
            $expected = "but 3 of them '@(1, 2, 3)' did not pass the filter."

            $customMessage = "but <actualFilteredCount> of them '<actualFiltered>' did not pass the filter."
            $data = @{
                actualFilteredCount = 3
                actualFiltered      = 1, 2, 3
            }

            Get-AssertionMessage -CustomMessage $customMessage -Data $data | Verify-Equal $expected
        }
    }
}
