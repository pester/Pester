Set-StrictMode -Version Latest

Describe "Should-BeLikeString" {
    Context "Case insensitive matching" {
        It "Passes give strings that have the same value" {
            Should-BeLikeString -Expected "abc" -Actual "abc"
        }

        It "Passes given strings with different case and same values. comparing '<actual>':'<expected>'" -TestCases @(
            @{ Actual = "ABc"; Expected = "abc" },
            @{ Actual = "aBc"; Expected = "abc" },
            @{ Actual = "ABC"; Expected = "abc" }
        ) {
            param ($Actual, $Expected)
            Should-BeLikeString -Actual $Actual -Expected $Expected
        }

        It "Fails given strings with different values" {
            { Should-BeLikeString -Expected "abc" -Actual "def" } | Verify-AssertionFailed
        }

        It "Fails given strings with different case and different values. comparing '<actual>':'<expected>'" -TestCases @(
            @{ Actual = "ABc"; Expected = "def" },
            @{ Actual = "aBc"; Expected = "def" },
            @{ Actual = "ABC"; Expected = "def" }
        ) {
            param ($Actual, $Expected)
            { Should-BeLikeString -Actual $Actual -Expected $Expected } | Verify-AssertionFailed
        }

        It "Fails given strings from which one is sorrounded by whitespace. comparing '<actual>':'<expected>'" -TestCases @(
            @{ Actual = "abc "; Expected = "abc" },
            @{ Actual = "abc "; Expected = "abc" },
            @{ Actual = "ab c"; Expected = "abc" }
        ) {
            param ($Actual, $Expected)
            { Should-BeLikeString -Actual $Actual -Expected $Expected } | Verify-AssertionFailed
        }

        It "Passes given strings with different case that start with a given pattern. comparing '<actual>':'<expected>'" -TestCases @(
            @{ Actual = "ABcdef"; Expected = "abc*" },
            @{ Actual = "aBcdef"; Expected = "abc*" },
            @{ Actual = "ABCDEF"; Expected = "abc*" }
        ) {
            param ($Actual, $Expected)
            Should-BeLikeString -Actual $Actual -Expected $Expected
        }

        It "Fails given strings with different case that start with a different pattern. comparing '<actual>':'<expected>'" -TestCases @(
            @{ Actual = "ABcdef"; Expected = "ghi*" },
            @{ Actual = "aBcdef"; Expected = "ghi*" },
            @{ Actual = "ABCDEF"; Expected = "ghi*" }
        ) {
            param ($Actual, $Expected)
            { Should-BeLikeString -Actual $Actual -Expected $Expected } | Verify-AssertionFailed
        }

        It "Passes given strings with different case that contain a given pattern. comparing '<actual>':'<expected>'" -TestCases @(
            @{ Actual = "ABcdef"; Expected = "*cd*" },
            @{ Actual = "aBcdef"; Expected = "*cd*" },
            @{ Actual = "ABCDEF"; Expected = "*CD*" }
        ) {
            param ($Actual, $Expected)
            Should-BeLikeString -Actual $Actual -Expected $Expected
        }

        It "Fails given strings with different case that contain a different pattern. comparing '<actual>':'<expected>'" -TestCases @(
            @{ Actual = "ABcdef"; Expected = "*gh*" },
            @{ Actual = "aBcdef"; Expected = "*gh*" },
            @{ Actual = "ABCDEF"; Expected = "*GH*" }
        ) {
            param ($Actual, $Expected)
            { Should-BeLikeString -Actual $Actual -Expected $Expected } | Verify-AssertionFailed
        }
    }

    Context "Case sensitive matching" {
        It "Fails given strings with different case but same values. comparing '<actual>':'<expected>'" -TestCases @(
            @{ Actual = "ABc"; Expected = "abc" },
            @{ Actual = "aBc"; Expected = "abc" },
            @{ Actual = "ABC"; Expected = "abc" }
        ) {
            param ($Actual, $Expected)
            { Should-BeLikeString -Actual $Actual -Expected $Expected -CaseSensitive } | Verify-AssertionFailed
        }
    }

    Context "Case sensitive matching" {
        It "Fails given strings with different case that contain the given pattern. comparing '<actual>':'<expected>'" -TestCases @(
            @{ Actual = "ABCDEF"; Expected = "*cd*" }
        ) {
            param ($Actual, $Expected)
            { Should-BeLikeString -Actual $Actual -Expected $Expected -CaseSensitive } | Verify-AssertionFailed
        }
    }

    It "Allows actual to be passed from pipeline" {
        "abc" | Should-BeLikeString -Expected "abc"
    }

    It "Allows expected to be passed by position" {
        Should-BeLikeString "abc" -Actual "abc"
    }

    It "Allows actual to be passed by pipeline and expected by position" {
        "abc" | Should-BeLikeString "abc"
    }

    It "Throws when given a collection to avoid confusing matches of the last item only" {
        $err = { "bde", "abc" | Should-BeLikeString -Expected "abc" } | Verify-Throw
        $err.Exception.Message | Verify-Equal "Actual is expected to be string, to avoid confusing behavior that -like operator exhibits with collections. To assert on collections use Should-Any, Should-All or some other collection assertion."
    }

    It "Can be called with positional parameters" {
        { Should-BeLikeString "a" "b" } | Verify-AssertionFailed
    }

    Context "Verify messages" {
        It "Given two values that are not alike '<actual>' and '<expected>' it returns the correct message '<message>'" -TestCases @(
            @{ Actual = 'a'; Expected = 'b'; Message = "Expected the string 'a' to be like 'b', but it did not." }
            @{ Actual = 'ab'; Expected = 'd*'; Message = "Expected the string 'ab' to be like 'd*', but it did not." }
            @{ Actual = 'something'; Expected = '*abc*'; Message = "Expected the string 'something' to be like '*abc*', but it did not." }
        ) {
            param ($Actual, $Expected, $Message)
            $err = { Should-BeLikeString -Actual $Actual -Expected $Expected } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal $Message
        }

        It "Given two values that are not alike becuase of case '<actual>' and '<expected>' it returns the correct message '<message>'" -TestCases @(
            @{ Actual = 'a'; Expected = 'B'; Message = "Expected the string 'a' to case sensitively be like 'B', but it did not." }
            @{ Actual = 'ab'; Expected = 'B*'; Message = "Expected the string 'ab' to case sensitively be like 'B*', but it did not." }
            @{ Actual = 'something'; Expected = '*SOME*'; Message = "Expected the string 'something' to case sensitively be like '*SOME*', but it did not." }
        ) {
            param ($Actual, $Expected, $Message)
            $err = { Should-BeLikeString -Actual $Actual -Expected $Expected -CaseSensitive } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal $Message
        }
    }
}
