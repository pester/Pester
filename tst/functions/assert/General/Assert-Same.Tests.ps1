InModuleScope -ModuleName Assert {
    Describe "Assert-Same" {
        It "Passes when two objects are the same instance" {
            $object = New-Object Diagnostics.Process
            $object | Assert-Same $object
        }

        It "Fails when two objects are different instance" {
            $object = New-Object Diagnostics.Process
            $object1 = New-Object Diagnostics.Process
            { $object | Assert-Same $object1 } | Verify-AssertionFailed
        }

        It "Fails for array input even if the last item is the same as expected" {
            $object = New-Object Diagnostics.Process
            { 1,2, $object | Assert-Same $object } | Verify-AssertionFailed
        }

        It "Fails with custom message" {
            $object = New-Object Diagnostics.Process
            $error = { "text" | Assert-Same $object -CustomMessage "'<expected>' is not '<actual>'" } | Verify-AssertionFailed
            $error.Exception.Message | Verify-Equal "'Diagnostics.Process{Id=; Name=}' is not 'text'"
        }

        It "Given two values that are not the same instance '<expected>' and '<actual>' it returns expected message '<message>'" -TestCases @(
            @{ Expected = New-Object -TypeName PSObject ; Actual = New-Object -TypeName PSObject ; Message = "Expected PSObject '', to be the same instance but it was not."}
        ) {
            param($Expected, $Actual, $Message)
            $error = { Assert-Same -Actual $Actual -Expected $Expected } | Verify-AssertionFailed
            $error.Exception.Message | Verify-Equal $Message
        }

        It "Returns the value on output" {
            $expected = New-Object Diagnostics.Process
            $expected | Assert-Same $expected | Verify-Equal $expected
        }

        Context "Throws when `$expected is a value type or string to warn user about unexpected behavior" {
            It "throws for value <value>" -TestCases @(
                @{ Value = 1 }
                @{ Value = 1.0D }
                @{ Value = 1.0 }
                @{ Value = 'c' }
                @{ Value = "abc" }
            ) {
                param($Value)

                $err = { "dummy" | Assert-Same -Expected $Value } | Verify-Throw
                $err.Exception | Verify-Type ([ArgumentException])
                $err.Exception.Message | Verify-Equal "Assert-Same compares objects by reference. You provided a value type or a string, those are not reference types and you most likely don't need to compare them by reference, see https://github.com/nohwnd/Assert/issues/6.`n`nAre you trying to compare two values to see if they are equal? Use Assert-Equal instead."
            }
        }

        It "Can be called with positional parameters" {
            $object = New-Object Diagnostics.Process
            { Assert-Same $object "abc" } | Verify-AssertionFailed
        }
    }
}