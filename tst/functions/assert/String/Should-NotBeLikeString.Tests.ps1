Set-StrictMode -Version Latest

Describe "Should-NotBeLikeString" {
    Context "Case insensitive matching" {
        It "Fails give strings that have the same value" {
            { Should-NotBeLikeString -Expected "abc" -Actual "abc" } | Verify-AssertionFailed
        }

        It "Fails given strings with different case and same values. comparing '<actual>':'<expected>'" -TestCases @(
            @{ Actual = "ABc"; Expected = "abc" },
            @{ Actual = "aBc"; Expected = "abc" },
            @{ Actual = "ABC"; Expected = "abc" }
        ) {
            { Should-NotBeLikeString -Actual $Actual -Expected $Expected } | Verify-AssertionFailed
        }

        It "Passes given strings with different values" {
            Should-NotBeLikeString -Expected "abc" -Actual "def"
        }

        It "Passes given strings with different case and different values. comparing '<actual>':'<expected>'" -TestCases @(
            @{ Actual = "ABc"; Expected = "def" },
            @{ Actual = "aBc"; Expected = "def" },
            @{ Actual = "ABC"; Expected = "def" }
        ) {
            Should-NotBeLikeString -Actual $Actual -Expected $Expected
        }

        It "Passes given strings from which one is sorrounded by whitespace. comparing '<actual>':'<expected>'" -TestCases @(
            @{ Actual = "abc "; Expected = "abc" },
            @{ Actual = "abc "; Expected = "abc" },
            @{ Actual = "ab c"; Expected = "abc" }
        ) {
            Should-NotBeLikeString -Actual $Actual -Expected $Expected
        }

        It "Fails given strings with different case that start with a given pattern. comparing '<actual>':'<expected>'" -TestCases @(
            @{ Actual = "ABcdef"; Expected = "abc*" },
            @{ Actual = "aBcdef"; Expected = "abc*" },
            @{ Actual = "ABCDEF"; Expected = "abc*" }
        ) {
            { Should-NotBeLikeString -Actual $Actual -Expected $Expected } | Verify-AssertionFailed
        }

        It "Passes given strings with different case that start with a different pattern. comparing '<actual>':'<expected>'" -TestCases @(
            @{ Actual = "ABcdef"; Expected = "ghi*" },
            @{ Actual = "aBcdef"; Expected = "ghi*" },
            @{ Actual = "ABCDEF"; Expected = "ghi*" }
        ) {
            Should-NotBeLikeString -Actual $Actual -Expected $Expected
        }

        It "Fails given strings with different case that contain a given pattern. comparing '<actual>':'<expected>'" -TestCases @(
            @{ Actual = "ABcdef"; Expected = "*cd*" },
            @{ Actual = "aBcdef"; Expected = "*cd*" },
            @{ Actual = "ABCDEF"; Expected = "*CD*" }
        ) {
            { Should-NotBeLikeString -Actual $Actual -Expected $Expected } | Verify-AssertionFailed
        }

        It "Passes given strings with different case that contain a different pattern. comparing '<actual>':'<expected>'" -TestCases @(
            @{ Actual = "ABcdef"; Expected = "*gh*" },
            @{ Actual = "aBcdef"; Expected = "*gh*" },
            @{ Actual = "ABCDEF"; Expected = "*GH*" }
        ) {
            Should-NotBeLikeString -Actual $Actual -Expected $Expected
        }
    }

    Context "Case sensitive matching" {
        It "Passes given strings with different case but same values. comparing '<actual>':'<expected>'" -TestCases @(
            @{ Actual = "ABc"; Expected = "abc" },
            @{ Actual = "aBc"; Expected = "abc" },
            @{ Actual = "ABC"; Expected = "abc" }
        ) {
            Should-NotBeLikeString -Actual $Actual -Expected $Expected -CaseSensitive
        }
    }

    Context "Case sensitive matching" {
        It "Passes given strings with different case that contain the given pattern. comparing '<actual>':'<expected>'" -TestCases @(
            @{ Actual = "ABCDEF"; Expected = "*cd*" }
        ) {
            Should-NotBeLikeString -Actual $Actual -Expected $Expected -CaseSensitive
        }
    }

    It "Allows actual to be passed from pipeline" {
        "efg" | Should-NotBeLikeString -Expected "abc"
    }

    It "Allows expected to be passed by position" {
        Should-NotBeLikeString "efg" -Actual "abc"
    }

    It "Allows actual to be passed by pipeline and expected by position" {
        "efg" | Should-NotBeLikeString "abc"
    }

    It "Can be called with positional parameters" {
        { Should-NotBeLikeString "a" "a" } | Verify-AssertionFailed
    }

    It "Throws when given a collection to avoid confusing matches of the last item only" {
        $err = { "bde", "abc" | Should-NotBeLikeString -Expected "abc" } | Verify-Throw
        $err.Exception.Message | Verify-Equal "Actual is expected to be string, to avoid confusing behavior that -like operator exhibits with collections. To assert on collections use Should-Any, Should-All or some other collection assertion."
    }

    Context "Verify messages" {
        It "Given two values that are alike '<actual>' and '<expected>' it returns the correct message '<message>'" -TestCases @(
            @{ Actual = 'a'; Expected = 'A'; Message = "Expected the string 'a' to not match 'A' but it matched it." }
            @{ Actual = 'ab'; Expected = 'a*'; Message = "Expected the string 'ab' to not match 'a*' but it matched it." }
            @{ Actual = 'something'; Expected = 'SOME*'; Message = "Expected the string 'something' to not match 'SOME*' but it matched it." }
        ) {
            $err = { Should-NotBeLikeString -Actual $Actual -Expected $Expected } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal $Message
        }

        It "Given two values that are alike becuase of case '<actual>' and '<expected>' it returns the correct message '<message>'" -TestCases @(
            @{ Actual = 'a'; Expected = 'a'; Message = "Expected the string 'a' to case sensitively not match 'a' but it matched it." }
            @{ Actual = 'AB'; Expected = 'A*'; Message = "Expected the string 'AB' to case sensitively not match 'A*' but it matched it." }
            @{ Actual = 'SOMETHING'; Expected = '*SOME*'; Message = "Expected the string 'SOMETHING' to case sensitively not match '*SOME*' but it matched it." }
        ) {
            $err = { Should-NotBeLikeString -Actual $Actual -Expected $Expected -CaseSensitive } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal $Message
        }
    }
}
