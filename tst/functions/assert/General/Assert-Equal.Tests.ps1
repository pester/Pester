InModuleScope -ModuleName Assert {
    Describe "Assert-Equal" {
        Context "Comparing strings" {
            It "Passes when two strings are equal" {
                "abc" | Assert-Equal "abc"
            }

            It "Fails when two strings are different" {
                { "abc" | Assert-Equal "bde" } | Verify-AssertionFailed
            }
        }

        Context "Comparing integers" {
            It "Passes when two numbers are equal" {
                1 | Assert-Equal 1
            }

            It "Fails when two numbers are different" {
                { 1 | Assert-Equal 9 } | Verify-AssertionFailed
            }
        }

        Context "Comparing doubles" {
            It "Passes when two numbers are equal" {
                .1 | Assert-Equal .1
            }

            It "Fails when two numbers are different" {
                { .1 | Assert-Equal .9 } | Verify-AssertionFailed
            }
        }

        Context "Comparing decimals" {
            It "Passes when two numbers are equal" {
                .1D | Assert-Equal .1D
            }

            It "Fails when two numbers are different" {
                { .1D | Assert-Equal .9D } | Verify-AssertionFailed
            }
        }

        Context "Comparing objects" {
            It "Passes when two objects are the same" {
                $object = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
                $object | Assert-Equal $object
            }

            It "Fails when two objects are different" {
                $object = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
                $object1 = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
                { $object | Assert-Equal $object1 } | Verify-AssertionFailed
            }
        }

        It "Fails for array input even if the last item is the same as expected" {
             {  1,2,3 | Assert-Equal 3 } | Verify-AssertionFailed
        }

        It "Fails with custom message" {
             $error = { 9 | Assert-Equal 3 -CustomMessage "<expected> is not <actual>" } | Verify-AssertionFailed
             $error.Exception.Message | Verify-Equal "3 is not 9"
        }

        Context "Validate messages" {
            It "Given two values that are not the same '<expected>' and '<actual>' it returns expected message '<message>'" -TestCases @(
                @{ Expected = "a" ; Actual = 10 ; Message = "Expected string 'a', but got int '10'."},
                @{ Expected = "a" ; Actual = 10.1 ; Message = "Expected string 'a', but got double '10.1'."},
                @{ Expected = "a" ; Actual = 10.1D ; Message = "Expected string 'a', but got decimal '10.1'."}
            ) {
                param($Expected, $Actual, $Message)
                $error = { Assert-Equal -Actual $Actual -Expected $Expected } | Verify-AssertionFailed
                $error.Exception.Message | Verify-Equal $Message
            }
        }

        It "Returns the value on output" {
            $expected = 1
            $expected | Assert-Equal 1 | Verify-Equal $expected
        }

        It "Can be called with positional parameters" {
            { Assert-Equal 1 2 } | Verify-AssertionFailed
        }

        It "Given collection to Expected it throws" {
            $error = { "dummy" | Assert-Equal @() } | Verify-Throw
            $error.Exception | Verify-Type ([ArgumentException])
        }
    }
}