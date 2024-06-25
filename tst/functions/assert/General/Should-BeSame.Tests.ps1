Set-StrictMode -Version Latest

Describe "Should-BeSame" {
    It "Passes when two objects are the same instance" {
        $object = New-Object Diagnostics.Process
        $object | Should-BeSame $object
    }

    It "Fails when two objects are different instance" {
        $object = New-Object Diagnostics.Process
        $object1 = New-Object Diagnostics.Process
        { $object | Should-BeSame $object1 } | Verify-AssertionFailed
    }

    It "Fails for array input even if the last item is the same as expected" {
        $object = New-Object Diagnostics.Process
        { 1, 2, $object | Should-BeSame $object } | Verify-AssertionFailed
    }

    It "Given two values that are not the same instance '<expected>' and '<actual>' it returns expected message '<message>'" -TestCases @(
        @{ Expected = New-Object -TypeName PSObject ; Actual = New-Object -TypeName PSObject ; Message = "Expected [PSObject] PSObject{}, to be the same instance but it was not. Actual: [PSObject] PSObject{}" }
    ) {
        $err = { Should-BeSame -Actual $Actual -Expected $Expected } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal $Message
    }

    Context "Throws when `$expected is a value type or string to warn user about unexpected behavior" {
        It "throws for value <value>" -TestCases @(
            @{ Value = 1 }
            @{ Value = 1.0D }
            @{ Value = 1.0 }
            @{ Value = 'c' }
            @{ Value = "abc" }
        ) {
            $err = { "dummy" | Should-BeSame -Expected $Value } | Verify-Throw
            $err.Exception | Verify-Type ([ArgumentException])
            $err.Exception.Message | Verify-Equal "Should-BeSame compares objects by reference. You provided a value type or a string, those are not reference types and you most likely don't need to compare them by reference, see https://github.com/nohwnd/Assert/issues/6.`n`nAre you trying to compare two values to see if they are equal? Use Should-BeEqual instead."
        }
    }

    It "Can be called with positional parameters" {
        $object = New-Object Diagnostics.Process
        { Should-BeSame $object "abc" } | Verify-AssertionFailed
    }
}
