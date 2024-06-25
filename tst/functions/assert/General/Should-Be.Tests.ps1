Set-StrictMode -Version Latest

Describe "Should-Be" {
    Context "Comparing strings" {
        It "Passes when two strings are equal" {
            "abc" | Should-Be "abc"
        }

        It "Fails when two strings are different" {
            { "abc" | Should-Be "bde" } | Verify-AssertionFailed
        }
    }

    Context "Comparing integers" {
        It "Passes when two numbers are equal" {
            1 | Should-Be 1
        }

        It "Fails when two numbers are different" {
            { 1 | Should-Be 9 } | Verify-AssertionFailed
        }
    }

    Context "Comparing doubles" {
        It "Passes when two numbers are equal" {
            .1 | Should-Be .1
        }

        It "Fails when two numbers are different" {
            { .1 | Should-Be .9 } | Verify-AssertionFailed
        }
    }

    Context "Comparing decimals" {
        It "Passes when two numbers are equal" {
            .1D | Should-Be .1D
        }

        It "Fails when two numbers are different" {
            { .1D | Should-Be .9D } | Verify-AssertionFailed
        }
    }

    Context "Comparing objects" {
        It "Passes when two objects are the same" {
            $object = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            $object | Should-Be $object
        }

        It "Fails when two objects are different" {
            $object = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            $object1 = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            { $object | Should-Be $object1 } | Verify-AssertionFailed
        }
    }

    It "Fails for array input even if the last item is the same as expected" {
        { 1, 2, 3 | Should-Be 3 } | Verify-AssertionFailed
    }

    Context "Validate messages" {
        It "Given two values that are not the same '<expected>' and '<actual>' it returns expected message '<message>'" -TestCases @(
            @{ Expected = "a" ; Actual = 10 ; Message = "Expected [string] 'a', but got [int] 10." },
            @{ Expected = "a" ; Actual = 10.1 ; Message = "Expected [string] 'a', but got [double] 10.1." },
            @{ Expected = "a" ; Actual = 10.1D ; Message = "Expected [string] 'a', but got [decimal] 10.1." }
        ) {
            $err = { Should-Be -Actual $Actual -Expected $Expected } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal $Message
        }
    }

    It "Can be called with positional parameters" {
        { Should-Be 1 2 } | Verify-AssertionFailed
    }

    It "Given collection to Expected it throws" {
        $err = { "dummy" | Should-Be @() } | Verify-Throw
        $err.Exception | Verify-Type ([ArgumentException])
    }
}
