Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Test-StringEqual" {
        Context "Type matching" {
            It "Returns false for non-string" {
                Test-StringEqual -Expected "1" -Actual 1 | Verify-False
            }
        }
        Context "Case insensitive matching" {
            It "strings with the same values are equal" {
                Test-StringEqual -Expected "abc" -Actual "abc" | Verify-True
            }

            It "strings with different case and same values are equal. comparing '<l>':'<r>'" -TestCases @(
                @{l = "ABc"; r = "abc" },
                @{l = "aBc"; r = "abc" },
                @{l = "ABC"; r = "abc" }
            ) {
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
                Test-StringEqual -Expected $l -Actual $r | Verify-False
            }

            It "strings from which one is sorrounded by whitespace are not equal. comparing '<l>':'<r>'" -TestCases @(
                @{l = "abc "; r = "abc" },
                @{l = "abc "; r = "abc" },
                @{l = "ab c"; r = "abc" }
            ) {
                Test-StringEqual -Expected $l -Actual $r | Verify-False
            }
        }

        Context "Case sensitive matching" {
            It "strings with different case but same values are not equal. comparing '<l>':'<r>'" -TestCases @(
                @{l = "ABc"; r = "abc" },
                @{l = "aBc"; r = "abc" },
                @{l = "ABC"; r = "abc" }
            ) {
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
                Test-StringEqual -Expected $l -Actual $r -IgnoreWhiteSpace | Verify-True
            }
        }
    }
}

Describe "Should-BeString" {
    It "Does nothing when string are the same" {
        Should-BeString -Expected "abc" -Actual "abc"
    }

    It "Throws when strings are different" {
        { Should-BeString -Expected "abc" -Actual "bde" } | Verify-AssertionFailed
    }

    It "Allows actual to be passed from pipeline" {
        "abc" | Should-BeString -Expected "abc"
    }

    It "Allows expected to be passed by position" {
        Should-BeString "abc" -Actual "abc"
    }

    It "Allows actual to be passed by pipeline and expected by position" {
        "abc" | Should-BeString "abc"
    }

    It "Fails when collection of strings is passed in by pipeline, even if the last string is the same as the expected string" {
        { "bde", "abc" | Should-BeString -Expected "abc" } | Verify-AssertionFailed
    }

    Context "String specific features" {
        It "Can compare strings in CaseSensitive mode" {
            { Should-BeString -Expected "ABC" -Actual "abc" -CaseSensitive } | Verify-AssertionFailed
        }

        It "Can compare strings without whitespace" {
            Should-BeString -Expected " a b c " -Actual "abc" -IgnoreWhitespace
        }

        It "Can compare strings without whitespace at the start or end" -ForEach @(
            @{ Value = " abc" }
            @{ Value = "abc " }
            @{ Value = "abc`t" }
            @{ Value = "`tabc" }
        ) {
            "  abc   " | Should-BeString -Expected "abc" -TrimWhitespace
        }

        It "Trimming whitespace does not remove it from inside of the string" {
            { "a bc" | Should-BeString -Expected "abc" -TrimWhitespace } | Verify-AssertionFailed
        }
    }

    It "Can be called with positional parameters" {
        { Should-BeString "a" "b" } | Verify-AssertionFailed
    }

    It "Throws with default message when test fails" {
        $err = { Should-BeString -Expected "abc" -Actual "bde" } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal "Expected [string] 'abc', but got [string] 'bde'."
    }
}
