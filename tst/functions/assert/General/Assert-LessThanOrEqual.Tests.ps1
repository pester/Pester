Describe "Assert-LessThanOrEqual" {
    Context "Comparing strings" {
        It "Passes when actual is less than expected" {
            "a" | Assert-LessThanOrEqual "z"
        }

        It "Passes when actual is equal to expected" {
            "a" | Assert-LessThanOrEqual "a"
        }

        It "Fails when actual is greater than expected" {
            { "z" | Assert-LessThanOrEqual "a" } | Verify-AssertionFailed
        }
    }

    Context "Comparing integers" {
        It "Passes when expected is less than actual" {
            1 | Assert-LessThanOrEqual 2
        }

        It "Passes when actual is equal to expected" {
            1 | Assert-LessThanOrEqual 1
        }

        It "Fails when actual is greater than expected" {
            { 9 | Assert-LessThanOrEqual 1 } | Verify-AssertionFailed
        }
    }

    Context "Comparing doubles" {
        It "Passes when expected is less than actual" {
            .1 | Assert-LessThanOrEqual .2
        }

        It "Passes when actual is equal to expected" {
            .1 | Assert-LessThanOrEqual .1
        }

        It "Fails when actual is greater than expected" {
            { .9 | Assert-LessThanOrEqual .1 } | Verify-AssertionFailed
        }
    }

    Context "Comparing decimals" {
        It "Passes when expected is less than actual" {
            1D | Assert-LessThanOrEqual 2D
        }

        It "Passes when actual is equal to expected" {
            1D | Assert-LessThanOrEqual 1D
        }

        It "Fails when actual is greater than expected" {
            { 9D | Assert-LessThanOrEqual 1D } | Verify-AssertionFailed
        }
    }

    Context "Comparing objects" {
        It "Passes when two objects are the same" {
            $object = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            $object | Assert-LessThanOrEqual $object
        }

        It "Fails when two objects are not comparable" {
            $object = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            $object1 = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            $err = { $object | Assert-LessThanOrEqual $object1 } | Verify-Throw
            $err.Exception | Verify-Type ([System.Management.Automation.ExtendedTypeSystemException])
        }
    }

    It "Fails for array input even if the last item is less than then expected value" {
            $err = { 4,3,2,1 | Assert-LessThanOrEqual 3 } | Verify-Throw
            $err.Exception | Verify-Type ([System.Management.Automation.RuntimeException])
    }

    It "Fails with custom message" {
            $err = { 3 | Assert-LessThanOrEqual 2 -CustomMessage "<actual> is not less than <expected>" } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "3 is not less than 2"
    }

    Context "Validate messages" {
        It "Given two values '<expected>' and '<actual>' it returns expected message '<message>'" -TestCases @(
            @{ Expected = "a" ; Actual = "z" ; Message = "Expected string 'z' to be less than or equal to string 'a', but it was not."},
            @{ Expected = 1.1 ; Actual = 10.1 ; Message = "Expected double '10.1' to be less than or equal to double '1.1', but it was not."},
            @{ Expected = 1.1D ; Actual = 10.1D ; Message = "Expected decimal '10.1' to be less than or equal to decimal '1.1', but it was not."}
        ) {
            param($Expected, $Actual, $Message)
            $error = { Assert-LessThanOrEqual -Actual $Actual -Expected $Expected } | Verify-AssertionFailed
            $error.Exception.Message | Verify-Equal $Message
        }
    }

    It "Returns the value on output" {
        $expected = 0
        $expected | Assert-LessThanOrEqual 1 | Verify-Equal $expected
    }

    It "Can be called with positional parameters" {
        { Assert-LessThanOrEqual 1 2 } | Verify-AssertionFailed
    }

    It "Given collection to Expected it throws" {
        $error = { "dummy" | Assert-LessThanOrEqual @() } | Verify-Throw
        $error.Exception | Verify-Type ([ArgumentException])
    }
}