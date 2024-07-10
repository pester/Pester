Set-StrictMode -Version Latest

Describe "Should-BeGreaterThanOrEqual" {
    Context "Comparing strings" {
        It "Passes when actual is greater than expected" {
            "z" | Should-BeGreaterThanOrEqual "a"
        }

        It "Passes when actual is equal to expected" {
            "a" | Should-BeGreaterThanOrEqual "a"
        }

        It "Fails when actual is lower than expected" {
            { "a" | Should-BeGreaterThanOrEqual "z" } | Verify-AssertionFailed
        }
    }

    Context "Comparing integers" {
        It "Passes when expected is greater than actual" {
            2 | Should-BeGreaterThanOrEqual 1
        }

        It "Passes when actual is equal to expected" {
            1 | Should-BeGreaterThanOrEqual 1
        }

        It "Fails when actual is lower than expected" {
            { 1 | Should-BeGreaterThanOrEqual 9 } | Verify-AssertionFailed
        }
    }

    Context "Comparing doubles" {
        It "Passes when expected is greater than actual" {
            .2 | Should-BeGreaterThanOrEqual .1
        }

        It "Passes when actual is equal to expected" {
            .1 | Should-BeGreaterThanOrEqual .1
        }

        It "Fails when actual is lower than expected" {
            { .1 | Should-BeGreaterThanOrEqual .9 } | Verify-AssertionFailed
        }
    }

    Context "Comparing decimals" {
        It "Passes when expected is greater than actual" {
            2D | Should-BeGreaterThanOrEqual 1D
        }

        It "Passes when actual is equal to expected" {
            1D | Should-BeGreaterThanOrEqual 1D
        }

        It "Fails when actual is lower than expected" {
            { 1D | Should-BeGreaterThanOrEqual 9D } | Verify-AssertionFailed
        }
    }

    Context "Comparing objects" {
        It "Passes when two objects are the same" {
            $object = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            $object | Should-BeGreaterThanOrEqual $object
        }

        It "Fails when two objects are not comparable" {
            $object = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            $object1 = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            $err = { $object | Should-BeGreaterThanOrEqual $object1 } | Verify-Throw
            $err.Exception | Verify-Type ([System.Management.Automation.ExtendedTypeSystemException])
        }
    }

    It "Fails for array input even if the last item is greater than then expected value" {
        $err = { 1, 2, 3, 4 | Should-BeGreaterThanOrEqual 3 } | Verify-Throw
        $err.Exception | Verify-Type ([System.Management.Automation.RuntimeException])
    }

    Context "Validate messages" {
        It "Given two values '<expected>' and '<actual>' it returns expected message '<message>'" -TestCases @(
            @{ Expected = "z" ; Actual = "a" ; Message = "Expected the actual value to be greater than or equal to [string] 'z', but it was not. Actual: [string] 'a'" },
            @{ Expected = 10.1 ; Actual = 1.1 ; Message = "Expected the actual value to be greater than or equal to [double] 10.1, but it was not. Actual: [double] 1.1" },
            @{ Expected = 10.1D ; Actual = 1.1D ; Message = "Expected the actual value to be greater than or equal to [decimal] 10.1, but it was not. Actual: [decimal] 1.1" }
        ) {
            $err = { Should-BeGreaterThanOrEqual -Actual $Actual -Expected $Expected } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal $Message
        }
    }

    It "Can be called with positional parameters" {
        { Should-BeGreaterThanOrEqual 2 1 } | Verify-AssertionFailed
    }

    It "Given collection to Expected it throws" {
        $err = { "dummy" | Should-BeGreaterThanOrEqual @() } | Verify-Throw
        $err.Exception | Verify-Type ([ArgumentException])
    }
}
