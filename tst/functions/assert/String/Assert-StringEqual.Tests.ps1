InModuleScope -ModuleName Assert {
    Describe "Test-StringEqual" {
        Context "Case insensitive matching" {
            It "strings with the same values are equal" {
                Test-StringEqual -Expected "abc" -Actual "abc" | Verify-True
            }

            It "strings with different case and same values are equal. comparing '<l>':'<r>'" -TestCases @(
                @{l = "ABc"; r = "abc" },
                @{l = "aBc"; r = "abc" },
                @{l = "ABC"; r = "abc" }
            ) {
                param ($l, $r)
                Test-StringEqual -Expected $l -Actual $r | Verify-True
            }

            It "strings with different values are not equal" {
                Test-StringEqual -Expected "abc" -Actual "def" | Verify-False
            }

            It "strings with different case and different values are not equal. comparing '<l>':'<r>'" -TestCases @(
                @{l = "ABc"; r = "def" },
                @{l = "aBc"; r = "def" },
                @{l = "ABC"; r = "def" }
            ) {
                param ($l, $r)
                Test-StringEqual -Expected $l -Actual $r | Verify-False
            }

            It "strings from which one is sorrounded by whitespace are not equal. comparing '<l>':'<r>'" -TestCases @(
                @{l = "abc "; r = "abc" },
                @{l = "abc "; r = "abc" },
                @{l = "ab c"; r = "abc" }
            ) {
                param ($l, $r)
                Test-StringEqual -Expected $l -Actual $r | Verify-False
            }
        }

        Context "Case sensitive matching" {
            It "strings with different case but same values are not equal. comparing '<l>':'<r>'" -TestCases @(
                @{l = "ABc"; r = "abc" },
                @{l = "aBc"; r = "abc" },
                @{l = "ABC"; r = "abc" }
            ) {
                param ($l, $r)
                Test-StringEqual -Expected $l -Actual $r -CaseSensitive | Verify-False
            }
        }

        Context "Case insensitive matching with ingoring whitespace" {
            It "strings sorrounded or containing whitespace are equal. comparing '<l>':'<r>'" -TestCases @(
                @{l = "abc "; r = "abc" },
                @{l = "abc "; r = "abc" },
                @{l = "ab c"; r = "abc" },
                @{l = "ab c"; r = "a b c" }
            ) {
                param ($l, $r)
                Test-StringEqual -Expected $l -Actual $r -IgnoreWhiteSpace | Verify-True
            }
        }
    }

    Describe "Get-StringEqualDefaultFailureMessage" {
        It "returns correct default message" {
            $expected = "Expected the string to be 'abc' but got 'bde'."
            $actual = Get-StringEqualDefaultFailureMessage -Expected "abc" -Actual "bde"
            $actual | Verify-Equal $expected
        }
    }

    Describe "Assert-StringEqual" {
        It "Does nothing when string are the same" {
            Assert-StringEqual -Expected "abc" -Actual "abc"
        }

        It "Throws when strings are different" {
            { Assert-StringEqual -Expected "abc" -Actual "bde" } | Verify-AssertionFailed
        }

        It "Throws with default message when test fails" {
            $expected = Get-StringEqualDefaultFailureMessage -Expected "abc" -Actual "bde"
            $exception = { Assert-StringEqual -Expected "abc" -Actual "bde" } | Verify-AssertionFailed
            "$exception" | Verify-Equal $expected
        }

        It "Throws with custom message when test fails" {
            $customMessage = "Test failed becasue it expected '<e>' but got '<a>'. What a shame!"
            $expected = Get-CustomFailureMessage -CustomMessage $customMessage -Expected "abc" -Actual "bde"
            $exception = { Assert-StringEqual -Expected "abc" -Actual "bde" -CustomMessage $customMessage } | Verify-AssertionFailed
            "$exception" | Verify-Equal $expected
        }

        It "Allows actual to be passed from pipeline" {
            "abc" | Assert-StringEqual -Expected "abc"
        }

        It "Allows expected to be passed by position" {
            Assert-StringEqual "abc" -Actual "abc"
        }

        It "Allows actual to be passed by pipeline and expected by position" {
            "abc" | Assert-StringEqual "abc"
        }

        It "Fails when collection of strings is passed in by pipeline, even if the last string is the same as the expected string" {
            { "bde", "abc" | Assert-StringEqual -Expected "abc" } | Verify-AssertionFailed
        }

        Context "String specific features" {
            It "Can compare strings in CaseSensitive mode" {
                { Assert-StringEqual -Expected "ABC" -Actual "abc" -CaseSensitive } | Verify-AssertionFailed
            }

            It "Can compare strings without whitespace" {
                Assert-StringEqual -Expected " a b c " -Actual "abc" -IgnoreWhitespace
            }
        }

        It "Can be called with positional parameters" {
            { Assert-StringEqual "a" "b" } | Verify-AssertionFailed
        }
    }
}