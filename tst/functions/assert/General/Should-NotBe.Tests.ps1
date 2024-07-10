Set-StrictMode -Version Latest

Describe "Should-NotBe" {
    Context "Comparing strings" {
        It "Fails when two strings are equal" {
            { "abc" | Should-NotBe "abc" } | Verify-AssertionFailed
        }

        It "Passes when two strings are different" {
            "abc" | Should-NotBe "bde"
        }
    }

    Context "Comparing integers" {
        It "Fails when two numbers are equal" {
            { 1 | Should-NotBe 1 } | Verify-AssertionFailed
        }

        It "Passes when two numbers are different" {
            1 | Should-NotBe 9
        }
    }

    Context "Comparing doubles" {
        It "Fails when two numbers are equal" {
            { .1 | Should-NotBe .1 } | Verify-AssertionFailed
        }

        It "Passes when two numbers are different" {
            .1 | Should-NotBe .9
        }
    }

    Context "Comparing decimals" {
        It "Fails when two numbers are equal" {
            { .1D | Should-NotBe .1D } | Verify-AssertionFailed
        }

        It "Passes when two numbers are different" {
            .1D | Should-NotBe .9D
        }
    }

    Context "Comparing objects" {
        It "Fails when two objects are the same" {
            $object = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            { $object | Should-NotBe $object } | Verify-AssertionFailed
        }

        It "Passes when two objects are different" {
            $object = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            $object1 = New-Object -TypeName PsObject -Property @{ Name = "Jakub" }
            $object | Should-NotBe $object1
        }
    }

    It "Passes for array input even if the last item is the same as expected" {
        1, 2, 3 | Should-NotBe 3
    }

    Context "Validate messages" {
        It "Given two values that are the same '<value>' it returns expected message '<message>'" -TestCases @(
            @{ Value = 1; Message = "Expected [int] 1, to be different than the actual value, but they were equal." }
        ) {
            param($Value, $Message)
            $err = { Should-NotBe -Actual $Value -Expected $Value } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal $Message
        }
    }

    It "Can be called with positional parameters" {
        { Should-NotBe 1 1 } | Verify-AssertionFailed
    }

    It "Given collection to Expected it throws" {
        $err = { "dummy" | Should-NotBe @() } | Verify-Throw
        $err.Exception | Verify-Type ([ArgumentException])
    }
}

