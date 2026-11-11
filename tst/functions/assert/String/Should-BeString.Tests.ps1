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

        Context "Normalizing newlines" {
            It "strings that differ only in line ending style are equal. comparing '<lName>':'<rName>'" -TestCases @(
                @{ l = "a`r`nb"; r = "a`nb"; lName = "CRLF"; rName = "LF" },
                @{ l = "a`rb"; r = "a`nb"; lName = "CR"; rName = "LF" },
                @{ l = "a`r`nb"; r = "a`rb"; lName = "CRLF"; rName = "CR" },
                @{ l = "a$([char]0x2028)b"; r = "a`nb"; lName = "LS"; rName = "LF" }
            ) {
                Test-StringEqual -Expected $l -Actual $r -NormalizeLineEnding | Verify-True
            }

            It "strings that differ in more than line ending style are not equal" {
                Test-StringEqual -Expected "a`r`nb" -Actual "a`nc" -NormalizeLineEnding | Verify-False
            }

            It "keeps newline positions, so extra blank lines still differ" {
                Test-StringEqual -Expected "a`r`nb" -Actual "a`r`n`r`nb" -NormalizeLineEnding | Verify-False
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

    Context "Empty expected string" {
        It "Passes when both expected and actual are empty strings" {
            Should-BeString -Expected "" -Actual ""
        }

        It "Passes when expected is empty and actual is passed by pipeline" {
            "" | Should-BeString -Expected ""
        }

        It "Passes when empty expected is passed by position" {
            "" | Should-BeString ""
        }

        It "Fails when expected is empty but actual is not" {
            { Should-BeString -Expected "" -Actual "abc" } | Verify-AssertionFailed
        }

        It "Throws with default message when expected is empty but actual is not" {
            $err = { Should-BeString -Expected "" -Actual "abc" } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal (@'
Expected strings to be the same, but they were different.
Expected length: 0
Actual length:   3
Strings differ at index 0.
Expected: ''
But was:  'abc'
           ^
'@ -replace "`r`n", "`n")
        }
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

        It "Can compare multi-line strings ignoring line ending style" {
            "line1`nline2" | Should-BeString -Expected "line1`r`nline2" -NormalizeLineEnding
        }

        It "Normalizing newlines still compares indentation and blank lines" {
            { "a`nb" | Should-BeString -Expected "a`n`nb" -NormalizeLineEnding } | Verify-AssertionFailed
        }
    }

    It "Can be called with positional parameters" {
        { Should-BeString "a" "b" } | Verify-AssertionFailed
    }

    It "Throws with default message when test fails" {
        $err = { Should-BeString -Expected "abc" -Actual "bde" } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal (@'
Expected strings to be the same, but they were different.
String lengths are both 3.
Strings differ at index 0.
Expected: 'abc'
But was:  'bde'
           ^
'@ -replace "`r`n", "`n")
    }

    It "Shows arrow at correct position for case-sensitive difference" {
        $err = { "hello world" | Should-BeString "Hello World" -CaseSensitive } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal (@'
Expected strings to be the same, but they were different.
String lengths are both 11.
Strings differ at index 0.
Expected: 'Hello World'
But was:  'hello world'
           ^
'@ -replace "`r`n", "`n")
    }

    It "Shows arrow with dashes for mid-string difference" {
        $err = { "abc" | Should-BeString "abcdef" } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal (@'
Expected strings to be the same, but they were different.
Expected length: 6
Actual length:   3
Strings differ at index 3.
Expected: 'abcdef'
But was:  'abc'
           ---^
'@ -replace "`r`n", "`n")
    }

    It "Shows expanded whitespace characters in diff" {
        $err = { "abc`ndef" | Should-BeString "abc`r`ndef" } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal (@'
Expected strings to be the same, but they were different.
Expected length: 8
Actual length:   7
Strings differ at index 3.
Expected: 'abc␍␊def'
But was:  'abc␊def'
           ---^
'@ -replace "`r`n", "`n")
    }
}

Describe "Should-BeString big strings" {
    It "Reports the differing line and its context instead of printing both strings" {
        # The case from #2951: comparing whole generated files. Printing 10 000 lines twice is not
        # something anyone can read, and a character offset into it is not actionable either.
        $actual = (1..40 | ForEach-Object { "Line {0:D2}" -f $_ }) -join "`n"
        $expected = $actual -replace 'Line 20', 'Line 99'

        $err = { $actual | Should-BeString $expected } | Verify-AssertionFailed
        $message = $err.Exception.Message

        $message | Verify-Like '*1 region differs.*'
        $message | Verify-Like '*19 19 |   Line 19*'
        $message | Verify-Like '*20    | - Line 99*'
        $message | Verify-Like '*   20 | + Line 20*'
        $message | Verify-Like '*21 21 |   Line 21*'
        # lines far from the difference are not printed, the whole string is not dumped
        if ($message -like '*Line 01*') { throw 'the whole string was printed' }
    }

    It "Shows every region that differs, not just the first" {
        # This is what a first differing line scan cannot do, and it is what comparing a snapshot
        # needs, because several things change at once (#3006).
        $actual = (1..40 | ForEach-Object { "Line {0:D2}" -f $_ }) -join "`n"
        $expected = ($actual -replace 'Line 05', 'Line 95') -replace 'Line 31', 'Line 77'

        $err = { $actual | Should-BeString $expected } | Verify-AssertionFailed
        $message = $err.Exception.Message

        $message | Verify-Like '*2 regions differ.*'
        $message | Verify-Like '* 5    | - Line 95*'
        $message | Verify-Like '*  5 | + Line 05*'
        $message | Verify-Like '*31    | - Line 77*'
        $message | Verify-Like '*   31 | + Line 31*'
    }

    It "Caps how many regions it prints and says how many were left out" {
        $actual = (1..120 | ForEach-Object { "setting$_ = $($_ * 10)" }) -join "`n"
        $expected = (1..120 | ForEach-Object { "setting$_ = $(if (3 -eq $_ % 10) { $_ * 10 + 1 } else { $_ * 10 })" }) -join "`n"

        $err = { $actual | Should-BeString $expected } | Verify-AssertionFailed
        $message = $err.Exception.Message

        $message | Verify-Like '*12 regions differ, showing the first 5.*'
        $message | Verify-Like '*7 more region(s) differ, not shown.*'
    }

    It "Keeps the line numbers of both sides when lines are added" {
        $expected = (1..12 | ForEach-Object { "Line {0:D2}" -f $_ }) -join "`n"
        $actual = ($expected -split "`n" | ForEach-Object { if ($_ -eq 'Line 06') { 'Line 06'; 'Line 06b' } else { $_ } }) -join "`n"

        $err = { $actual | Should-BeString $expected } | Verify-AssertionFailed
        $message = $err.Exception.Message

        $message | Verify-Like '*Expected 12 line(s), actual 13 line(s).*'
        # the added line has no expected number, and everything after it is offset by one
        $message | Verify-Like '*  7 | + Line 06b*'
        $message | Verify-Like '* 7  8 |   Line 07*'
    }

    It "Makes a trailing space and a tab visible on the lines that differ" {
        $expected = (@('first', '  indented', 'no trailing space') + (1..9 | ForEach-Object { "filler $_" })) -join "`n"
        $actual = (@('first', "`tindented", 'no trailing space   ') + (1..9 | ForEach-Object { "filler $_" })) -join "`n"

        $err = { $actual | Should-BeString $expected } | Verify-AssertionFailed
        $message = $err.Exception.Message

        # tab shown as its control picture, trailing spaces as middle dots
        $message | Verify-Like "*+ $([char]0x2409)indented*"
        $message | Verify-Like "*+ no trailing space$([char]0xB7)$([char]0xB7)$([char]0xB7)*"
        # the context lines are left alone
        $message | Verify-Like '*|   first*'
    }

    It "Says so when every line matches and only the line endings differ" {
        $lf = (1..20 | ForEach-Object { "Line $_" }) -join "`n"
        $crlf = (1..20 | ForEach-Object { "Line $_" }) -join "`r`n"

        $err = { $crlf | Should-BeString $lf } | Verify-AssertionFailed
        $message = $err.Exception.Message

        $message | Verify-Like '*Every line is the same, only the line endings differ.*'
        $message | Verify-Like '*Expected: 19 LF*'
        $message | Verify-Like '*But was:  19 CRLF*'
        $message | Verify-Like '*-NormalizeLineEnding*'
    }

    It "Truncates a long single line around the difference" {
        $actual = ('x' * 200) + 'A' + ('y' * 200)
        $expected = ('x' * 200) + 'B' + ('y' * 200)

        $err = { $actual | Should-BeString $expected } | Verify-AssertionFailed
        $message = $err.Exception.Message

        $message | Verify-Like '*Strings differ at index 200.*'
        $message | Verify-Like "*Expected: '...*...'*"
        # the excerpt is far shorter than the 401 character strings it came from
        $line = ($message -split "`n") | Where-Object { $_ -like "Expected: '*" }
        if (200 -lt $line.Length) { throw "excerpt was not truncated, it is $($line.Length) characters" }
    }
}
