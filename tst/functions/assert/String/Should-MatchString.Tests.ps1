Set-StrictMode -Version Latest

Describe "Should-MatchString" {
    Context "Case insensitive matching" {
        It "Passes when the string matches the regular expression" {
            Should-MatchString -Expected "foo.*bar" -Actual "foobar"
        }

        It "Passes for strings with different case" {
            Should-MatchString -Expected "FOO.*BAR" -Actual "foobar"
        }

        It "Passes for multiple regex examples. comparing '<actual>':'<expected>'" -TestCases @(
            @{ Actual = "abc123"; Expected = "^[a-z]+\d+$" }
            @{ Actual = "hello world"; Expected = "^hello\s+world$" }
            @{ Actual = "abc"; Expected = "^[A-Z]+$" }
        ) {
            param ($Actual, $Expected)
            Should-MatchString -Actual $Actual -Expected $Expected
        }

        It "Fails when the regular expression does not match" {
            { Should-MatchString -Expected "^\d+$" -Actual "foobar" } | Should -Throw -ErrorId "PesterAssertionFailed"
        }
    }

    Context "Case sensitive matching" {
        It "Fails when only case-insensitive matching would succeed" {
            { Should-MatchString -Actual "foobar" -Expected "FOO.*BAR" -CaseSensitive } | Should -Throw -ErrorId "PesterAssertionFailed"
        }

        It "Passes when the case-sensitive pattern matches" {
            Should-MatchString -Actual "FooBar" -Expected "Foo.*Bar" -CaseSensitive
        }
    }

    It "Allows actual to be passed from pipeline" {
        "abc123" | Should-MatchString -Expected "^[a-z]+\d+$"
    }

    It "Allows expected to be passed by position" {
        Should-MatchString "^[a-z]+\d+$" -Actual "abc123"
    }

    It "Allows actual to be passed by pipeline and expected by position" {
        "abc123" | Should-MatchString "^[a-z]+\d+$"
    }

    It "Throws when given a collection as actual" {
        $err = { "abc", "def" | Should-MatchString -Expected "abc" } | Should -Throw -PassThru
        $err.Exception.Message | Should -Be "Actual is expected to be string, to avoid confusing behavior that -match operator exhibits with collections. To assert on collections use Should-Any, Should-All or some other collection assertion."
    }

    It "Throws when given a non-string pattern" {
        $err = { Should-MatchString -Actual "abc" -Expected 123 } | Should -Throw -PassThru
        $err.Exception.Message | Should -Be "Expected is expected to be string, to avoid confusing behavior that -match operator exhibits with collections."
    }

    It "Can be called with positional parameters" {
        { Should-MatchString "^\d+$" "abc" } | Should -Throw -ErrorId "PesterAssertionFailed"
    }

    Context "Verify messages" {
        It "Returns the correct message for failed matches" {
            $err = { Should-MatchString -Actual "ab" -Expected "\d" -Because "reason" } | Should -Throw -PassThru
            $err.Exception.Message | Should -Be "Expected the string 'ab' to match pattern '\d', because reason, but it did not."
        }

        It "Returns the correct message for failed case-sensitive matches" {
            $err = { Should-MatchString -Actual "ab" -Expected "AB" -CaseSensitive } | Should -Throw -PassThru
            $err.Exception.Message | Should -Be "Expected the string 'ab' to case sensitively match pattern 'AB', but it did not."
        }
    }
}

Describe "Should-NotMatchString" {
    Context "Case insensitive matching" {
        It "Passes when the string does not match the regular expression" {
            Should-NotMatchString -Expected "^\d+$" -Actual "foobar"
        }

        It "Fails when the string matches the regular expression" {
            { Should-NotMatchString -Expected "foo.*bar" -Actual "foobar" } | Should -Throw -ErrorId "PesterAssertionFailed"
        }

        It "Fails for strings with different case" {
            { Should-NotMatchString -Expected "FOO.*BAR" -Actual "foobar" } | Should -Throw -ErrorId "PesterAssertionFailed"
        }

        It "Passes for multiple regex examples. comparing '<actual>':'<expected>'" -TestCases @(
            @{ Actual = "abc123"; Expected = "^\d+$" }
            @{ Actual = "hello world"; Expected = "^goodbye$" }
            @{ Actual = "abc"; Expected = "^\d{3}$" }
        ) {
            param ($Actual, $Expected)
            Should-NotMatchString -Actual $Actual -Expected $Expected
        }
    }

    Context "Case sensitive matching" {
        It "Passes when only case-insensitive matching would succeed" {
            Should-NotMatchString -Actual "foobar" -Expected "FOO.*BAR" -CaseSensitive
        }

        It "Fails when the case-sensitive pattern matches" {
            { Should-NotMatchString -Actual "FooBar" -Expected "Foo.*Bar" -CaseSensitive } | Should -Throw -ErrorId "PesterAssertionFailed"
        }
    }

    It "Allows actual to be passed from pipeline" {
        "abc123" | Should-NotMatchString -Expected "^\d+$"
    }

    It "Allows expected to be passed by position" {
        Should-NotMatchString "^\d+$" -Actual "abc123"
    }

    It "Allows actual to be passed by pipeline and expected by position" {
        "abc123" | Should-NotMatchString "^\d+$"
    }

    It "Throws when given a collection as actual" {
        $err = { "abc", "def" | Should-NotMatchString -Expected "abc" } | Should -Throw -PassThru
        $err.Exception.Message | Should -Be "Actual is expected to be string, to avoid confusing behavior that -match operator exhibits with collections. To assert on collections use Should-Any, Should-All or some other collection assertion."
    }

    It "Throws when given a non-string pattern" {
        $err = { Should-NotMatchString -Actual "abc" -Expected 123 } | Should -Throw -PassThru
        $err.Exception.Message | Should -Be "Expected is expected to be string, to avoid confusing behavior that -match operator exhibits with collections."
    }

    It "Can be called with positional parameters" {
        { Should-NotMatchString "^a" "abc" } | Should -Throw -ErrorId "PesterAssertionFailed"
    }

    Context "Verify messages" {
        It "Returns the correct message for failed non-matches" {
            $err = { Should-NotMatchString -Actual "ab" -Expected ".*" -Because "reason" } | Should -Throw -PassThru
            $err.Exception.Message | Should -Be "Expected the string 'ab' to not match pattern '.*', because reason, but it matched it."
        }

        It "Returns the correct message for failed case-sensitive non-matches" {
            $err = { Should-NotMatchString -Actual "AB" -Expected "A.*" -CaseSensitive } | Should -Throw -PassThru
            $err.Exception.Message | Should -Be "Expected the string 'AB' to case sensitively not match pattern 'A.*', but it matched it."
        }
    }
}
