Set-StrictMode -Version Latest

Describe "Should-BeLessThan" {
    Context "Comparing strings" {
        It "Passes when actual is less than expected" {
            "a" | Should-BeLessThan "z"
        }

        It "Fails when actual is equal to expected" {
            { "z" | Should-BeLessThan "z" } | Verify-AssertionFailed
        }

        It "Fails when actual is greater than expected" {
            { "z" | Should-BeLessThan "a" } | Verify-AssertionFailed
        }
    }

    Context "Comparing integers" {
        It "Passes when expected is less than actual" {
            1 | Should-BeLessThan 2
        }

        It "Fails when actual is equal to expected" {
            { 1 | Should-BeLessThan 1 } | Verify-AssertionFailed
        }

        It "Fails when actual is greater than expected" {
            { 9 | Should-BeLessThan 1 } | Verify-AssertionFailed
        }
    }

    Context "Comparing doubles" {
        It "Passes when expected is less than actual" {
            .1 | Should-BeLessThan .2
        }

        It "Fails when actual is equal to expected" {
            { .1 | Should-BeLessThan .1 } | Verify-AssertionFailed
        }

        It "Fails when actual is greater than expected" {
            { .9 | Should-BeLessThan .1 } | Verify-AssertionFailed
        }
    }

    Context "Comparing decimals" {
        It "Passes when expected is less than actual" {
            1D | Should-BeLessThan 2D
        }

        It "Fails when actual is equal to expected" {
            { 1D | Should-BeLessThan 1D } | Verify-AssertionFailed
        }

        It "Fails when actual is greater than expected" {
            { 9D | Should-BeLessThan 1D } | Verify-AssertionFailed
        }
    }

    Context "Comparing objects" {
        It "Fails when two objects are the same" {
            $object = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            { $object | Should-BeLessThan $object } | Verify-AssertionFailed
        }

        It "Fails when two objects are not comparable" {
            $object = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            $object1 = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            $err = { $object | Should-BeLessThan $object1 } | Verify-Throw
            $err.Exception | Verify-Type ([System.Management.Automation.ExtendedTypeSystemException])
        }
    }

    It "Fails for array input even if the last item is less than the expected value" {
        $err = { 4, 3, 2, 1 | Should-BeLessThan 3 } | Verify-Throw
        $err.Exception | Verify-Type ([System.Management.Automation.RuntimeException])
    }

    Context "Validate messages" {
        It "Given two values '<expected>' and '<actual>' it returns expected message '<message>'" -TestCases @(
            @{ Expected = "a" ; Actual = "z" ; Message = "Expected the actual value to be less than [string] 'a', but it was not. Actual: [string] 'z'" },
            @{ Expected = 1.1 ; Actual = 10.1 ; Message = "Expected the actual value to be less than [double] 1.1, but it was not. Actual: [double] 10.1" },
            @{ Expected = 1.1D ; Actual = 10.1D ; Message = "Expected the actual value to be less than [decimal] 1.1, but it was not. Actual: [decimal] 10.1" }
        ) {
            $err = { Should-BeLessThan -Actual $Actual -Expected $Expected } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal $Message
        }
    }

    It "Given collection to Expected it throws" {
        $err = { "dummy" | Should-BeLessThan @() } | Verify-Throw
        $err.Exception | Verify-Type ([ArgumentException])
    }
}
