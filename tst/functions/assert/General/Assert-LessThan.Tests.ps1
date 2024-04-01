Describe "Assert-LessThan" {
    Context "Comparing strings" {
        It "Passes when actual is less than expected" {
            "a" | Assert-LessThan "z"
        }

        It "Fails when actual is equal to expected" {
            { "z" | Assert-LessThan "z" } | Verify-AssertionFailed
        }

        It "Fails when actual is greater than expected" {
            { "z" | Assert-LessThan "a" } | Verify-AssertionFailed
        }
    }

    Context "Comparing integers" {
        It "Passes when expected is less than actual" {
            1 | Assert-LessThan 2
        }

        It "Fails when actual is equal to expected" {
            { 1 | Assert-LessThan 1 } | Verify-AssertionFailed
        }

        It "Fails when actual is greater than expected" {
            { 9 | Assert-LessThan 1 } | Verify-AssertionFailed
        }
    }

    Context "Comparing doubles" {
        It "Passes when expected is less than actual" {
            .1 | Assert-LessThan .2
        }

        It "Fails when actual is equal to expected" {
            { .1 | Assert-LessThan .1 } | Verify-AssertionFailed
        }

        It "Fails when actual is greater than expected" {
            { .9 | Assert-LessThan .1 } | Verify-AssertionFailed
        }
    }

    Context "Comparing decimals" {
        It "Passes when expected is less than actual" {
            1D | Assert-LessThan 2D
        }

        It "Fails when actual is equal to expected" {
            { 1D | Assert-LessThan 1D } | Verify-AssertionFailed
        }

        It "Fails when actual is greater than expected" {
            { 9D | Assert-LessThan 1D } | Verify-AssertionFailed
        }
    }

    Context "Comparing objects" {
        It "Fails when two objects are the same" {
            $object = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            { $object | Assert-LessThan $object } | Verify-AssertionFailed
        }

        It "Fails when two objects are not comparable" {
            $object = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            $object1 = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            $err = { $object | Assert-LessThan $object1 } | Verify-Throw
            $err.Exception | Verify-Type ([System.Management.Automation.ExtendedTypeSystemException])
        }
    }

    It "Fails for array input even if the last item is less than the expected value" {
            $err = {  4,3,2,1 | Assert-LessThan 3 } | Verify-Throw
            $err.Exception | Verify-Type ([System.Management.Automation.RuntimeException])
    }

    It "Fails with custom message" {
            $err = { 3 | Assert-LessThan 2 -CustomMessage "<actual> is not less than <expected>" } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "3 is not less than 2"
    }

    Context "Validate messages" {
        It "Given two values '<expected>' and '<actual>' it returns expected message '<message>'" -TestCases @(
            @{ Expected = "a" ; Actual = "z" ; Message = "Expected string 'z' to be less than string 'a', but it was not."},
            @{ Expected = 1.1 ; Actual = 10.1 ; Message = "Expected double '10.1' to be less than double '1.1', but it was not."},
            @{ Expected = 1.1D ; Actual = 10.1D ; Message = "Expected decimal '10.1' to be less than decimal '1.1', but it was not."}
        ) {
            param($Expected, $Actual, $Message)
            $error = { Assert-LessThan -Actual $Actual -Expected $Expected } | Verify-AssertionFailed
            $error.Exception.Message | Verify-Equal $Message
        }
    }

    It "Returns the value on output" {
        $expected = 0
        $expected | Assert-LessThan 1 | Verify-Equal $expected
    }

    It "Can be called with positional parameters" {
        { Assert-LessThan 1 2 } | Verify-AssertionFailed
    }

    It "Given collection to Expected it throws" {
        $error = { "dummy" | Assert-LessThan @() } | Verify-Throw
        $error.Exception | Verify-Type ([ArgumentException])
    }
}