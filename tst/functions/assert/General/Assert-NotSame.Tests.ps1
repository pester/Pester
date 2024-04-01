InModuleScope -ModuleName Assert {
    Describe "Assert-NotSame" {
        It "Fails when two objects are the same instance" {
            $object = New-Object Diagnostics.Process
            { $object | Assert-NotSame $object } | Verify-AssertionFailed
        }

        It "Passes when two objects are different instance" {
            $object = New-Object Diagnostics.Process
            $object1 = New-Object Diagnostics.Process
            $object | Assert-NotSame $object1
        }

        It "Passes for array input even if the last item is the same as expected" {
            $object = New-Object Diagnostics.Process
            1,2, $object | Assert-NotSame $object
        }

        It "Fails with custom message" {
            $object = 1
            $error = { $object | Assert-NotSame $object -CustomMessage "<expected> is <actual>" } | Verify-AssertionFailed
            $error.Exception.Message | Verify-Equal "1 is 1"
        }

        It "Given two values that are the same instance it returns expected message '<message>'" -TestCases @(
            @{ Value = "a"; Message = "Expected string 'a', to not be the same instance."}
        ) {
            param($Value, $Message)
            $error = { Assert-NotSame -Actual $Value -Expected $Value } | Verify-AssertionFailed
            $error.Exception.Message | Verify-Equal $Message
        }

        It "Returns the value on output" {
            $expected = 1
            $expected | Assert-NotSame 7 | Verify-Equal $expected
        }

        It "Can be called with positional parameters" {
            {
                $obj = New-Object -TypeName PSObject
                Assert-NotSame $obj $obj
            } | Verify-AssertionFailed
        }
    }
}