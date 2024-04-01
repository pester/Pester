InModuleScope -ModuleName Assert {
    Describe "Assert-NotEqual" {
        Context "Comparing strings" {
            It "Fails when two strings are equal" {
                { "abc" | Assert-NotEqual "abc" } | Verify-AssertionFailed
            }

            It "Passes when two strings are different" {
                "abc" | Assert-NotEqual "bde"
            }
        }

        Context "Comparing integers" {
            It "Fails when two numbers are equal" {
                { 1 | Assert-NotEqual 1 } | Verify-AssertionFailed
            }

            It "Passes when two numbers are different" {
                1 | Assert-NotEqual 9
            }
        }

        Context "Comparing doubles" {
            It "Fails when two numbers are equal" {
                { .1 | Assert-NotEqual .1 } | Verify-AssertionFailed
            }

            It "Passes when two numbers are different" {
                .1 | Assert-NotEqual .9
            }
        }

        Context "Comparing decimals" {
            It "Fails when two numbers are equal" {
                { .1D | Assert-NotEqual .1D } | Verify-AssertionFailed
            }

            It "Passes when two numbers are different" {
                .1D | Assert-NotEqual .9D
            }
        }

        Context "Comparing objects" {
            It "Fails when two objects are the same" {
                $object = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
                { $object | Assert-NotEqual $object } | Verify-AssertionFailed
            }

            It "Passes when two objects are different" {
                $object = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
                $object1 = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
                $object | Assert-NotEqual $object1
            }
        }

        It "Passes for array input even if the last item is the same as expected" {
             1,2,3 | Assert-NotEqual 3
        }

        It "Fails with custom message" {
            $error = { 3 | Assert-NotEqual 3 -CustomMessage "<expected> is <actual>" } | Verify-AssertionFailed
            $error.Exception.Message | Verify-Equal "3 is 3"
        }

        Context "Validate messages" {
            It "Given two values that are the same '<value>' it returns expected message '<message>'" -TestCases @(
                @{ Value = 1;  Message = "Expected int '1', to be different than the actual value, but they were the same."}
            ) {
                param($Value, $Message)
                $error = { Assert-NotEqual -Actual $Value -Expected $Value } | Verify-AssertionFailed
                $error.Exception.Message | Verify-Equal $Message
            }
        }

        It "Returns the value on output" {
            $expected = 1
            $expected | Assert-NotEqual 9 | Verify-Equal $expected
        }

        It "Can be called with positional parameters" {
            { Assert-NotEqual 1 1 } | Verify-AssertionFailed
        }

        It "Given collection to Expected it throws" {
            $error = { "dummy" | Assert-NotEqual @() } | Verify-Throw
            $error.Exception | Verify-Type ([ArgumentException])
        }
    }
}