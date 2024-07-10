Set-StrictMode -Version Latest

Describe "Should-BeGreaterThan" {
    Context "Comparing strings" {
        It "Passes when actual is greater than expected" {
            "z" | Should-BeGreaterThan "a"
        }

        It "Fails when actual is equal to expected" {
            { "a" | Should-BeGreaterThan "a" } | Verify-AssertionFailed
        }

        It "Fails when actual is lower than expected" {
            { "a" | Should-BeGreaterThan "z" } | Verify-AssertionFailed
        }
    }

    Context "Comparing integers" {
        It "Passes when expected is greater than actual" {
            2 | Should-BeGreaterThan 1
        }

        It "Fails when actual is equal to expected" {
            { 1 | Should-BeGreaterThan 1 } | Verify-AssertionFailed
        }

        It "Fails when actual is lower than expected" {
            { 1 | Should-BeGreaterThan 9 } | Verify-AssertionFailed
        }
    }

    Context "Comparing doubles" {
        It "Passes when expected is greater than actual" {
            .2 | Should-BeGreaterThan .1
        }

        It "Fails when actual is equal to expected" {
            { .1 | Should-BeGreaterThan .1 } | Verify-AssertionFailed
        }

        It "Fails when actual is lower than expected" {
            { .1 | Should-BeGreaterThan .9 } | Verify-AssertionFailed
        }
    }

    Context "Comparing decimals" {
        It "Passes when expected is greater than actual" {
            2D | Should-BeGreaterThan 1D
        }

        It "Fails when actual is equal to expected" {
            { 1D | Should-BeGreaterThan 1D } | Verify-AssertionFailed
        }

        It "Fails when actual is lower than expected" {
            { 1D | Should-BeGreaterThan 9D } | Verify-AssertionFailed
        }
    }

    Context "Comparing objects" {
        It "Fails when two objects are the same" {
            $object = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            { $object | Should-BeGreaterThan $object } | Verify-AssertionFailed
        }

        It "Fails when two objects are not comparable" {
            $object = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            $object1 = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            $err = { $object | Should-BeGreaterThan $object1 } | Verify-Throw
            $err.Exception | Verify-Type ([System.Management.Automation.ExtendedTypeSystemException])
        }
    }

    It "Fails for array input even if the last item is greater than then expected value" {
        $err = { 1, 2, 3, 4 | Should-BeGreaterThan 3 } | Verify-Throw
        $err.Exception | Verify-Type ([System.Management.Automation.RuntimeException])
    }

    Context "Validate messages" {
        It "Given two values '<expected>' and '<actual>' it returns expected message '<message>'" -TestCases @(
            @{ Expected = "z" ; Actual = "a" ; Message = "Expected the actual value to be greater than [string] 'z', but it was not. Actual: [string] 'a'" },
            @{ Expected = 10.1 ; Actual = 1.1 ; Message = "Expected the actual value to be greater than [double] 10.1, but it was not. Actual: [double] 1.1" },
            @{ Expected = 10.1D ; Actual = 1.1D ; Message = "Expected the actual value to be greater than [decimal] 10.1, but it was not. Actual: [decimal] 1.1" }
        ) {
            $err = { Should-BeGreaterThan -Actual $Actual -Expected $Expected } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal $Message
        }
    }

    It "Can be called with positional parameters" {
        { Should-BeGreaterThan 2 1 } | Verify-AssertionFailed
    }

    It "Given collection to Expected it throws" {
        $err = { "dummy" | Should-BeGreaterThan @() } | Verify-Throw
        $err.Exception | Verify-Type ([ArgumentException])
    }
}
