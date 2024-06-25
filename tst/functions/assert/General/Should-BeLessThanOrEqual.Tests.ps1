Set-StrictMode -Version Latest

Describe "Should-BeLessThanOrEqual" {
    Context "Comparing strings" {
        It "Passes when actual is less than expected" {
            "a" | Should-BeLessThanOrEqual "z"
        }

        It "Passes when actual is equal to expected" {
            "a" | Should-BeLessThanOrEqual "a"
        }

        It "Fails when actual is greater than expected" {
            { "z" | Should-BeLessThanOrEqual "a" } | Verify-AssertionFailed
        }
    }

    Context "Comparing integers" {
        It "Passes when expected is less than actual" {
            1 | Should-BeLessThanOrEqual 2
        }

        It "Passes when actual is equal to expected" {
            1 | Should-BeLessThanOrEqual 1
        }

        It "Fails when actual is greater than expected" {
            { 9 | Should-BeLessThanOrEqual 1 } | Verify-AssertionFailed
        }
    }

    Context "Comparing doubles" {
        It "Passes when expected is less than actual" {
            .1 | Should-BeLessThanOrEqual .2
        }

        It "Passes when actual is equal to expected" {
            .1 | Should-BeLessThanOrEqual .1
        }

        It "Fails when actual is greater than expected" {
            { .9 | Should-BeLessThanOrEqual .1 } | Verify-AssertionFailed
        }
    }

    Context "Comparing decimals" {
        It "Passes when expected is less than actual" {
            1D | Should-BeLessThanOrEqual 2D
        }

        It "Passes when actual is equal to expected" {
            1D | Should-BeLessThanOrEqual 1D
        }

        It "Fails when actual is greater than expected" {
            { 9D | Should-BeLessThanOrEqual 1D } | Verify-AssertionFailed
        }
    }

    Context "Comparing objects" {
        It "Passes when two objects are the same" {
            $object = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            $object | Should-BeLessThanOrEqual $object
        }

        It "Fails when two objects are not comparable" {
            $object = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            $object1 = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            $err = { $object | Should-BeLessThanOrEqual $object1 } | Verify-Throw
            $err.Exception | Verify-Type ([System.Management.Automation.ExtendedTypeSystemException])
        }
    }

    It "Fails for array input even if the last item is less than then expected value" {
        $err = { 4, 3, 2, 1 | Should-BeLessThanOrEqual 3 } | Verify-Throw
        $err.Exception | Verify-Type ([System.Management.Automation.RuntimeException])
    }

    Context "Validate messages" {
        It "Given two values '<expected>' and '<actual>' it returns expected message '<message>'" -TestCases @(
            @{ Expected = "a" ; Actual = "z" ; Message = "Expected the actual value to be less than or equal to [string] 'a', but it was not. Actual: [string] 'z'" },
            @{ Expected = 1.1 ; Actual = 10.1 ; Message = "Expected the actual value to be less than or equal to [double] 1.1, but it was not. Actual: [double] 10.1" },
            @{ Expected = 1.1D ; Actual = 10.1D ; Message = "Expected the actual value to be less than or equal to [decimal] 1.1, but it was not. Actual: [decimal] 10.1" }
        ) {
            $err = { Should-BeLessThanOrEqual -Actual $Actual -Expected $Expected } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal $Message
        }
    }

    It "Can be called with positional parameters" {
        { Should-BeLessThanOrEqual 1 2 } | Verify-AssertionFailed
    }

    It "Given collection to Expected it throws" {
        $err = { "dummy" | Should-BeLessThanOrEqual @() } | Verify-Throw
        $err.Exception | Verify-Type ([ArgumentException])
    }
}
