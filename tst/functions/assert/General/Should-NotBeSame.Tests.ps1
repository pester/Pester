﻿Set-StrictMode -Version Latest

Describe "Should-NotBeSame" {
    It "Fails when two objects are the same instance" {
        $object = New-Object Diagnostics.Process
        { $object | Should-NotBeSame $object } | Verify-AssertionFailed
    }

    It "Passes when two objects are different instance" {
        $object = New-Object Diagnostics.Process
        $object1 = New-Object Diagnostics.Process
        $object | Should-NotBeSame $object1
    }

    It "Passes for array input even if the last item is the same as expected" {
        $object = New-Object Diagnostics.Process
        1, 2, $object | Should-NotBeSame $object
    }

    It "Given two values that are the same instance it returns expected message '<message>'" -TestCases @(
        @{ Value = "a"; Message = "Expected [string] ''a'', to not be the same instance." }
    ) {
        param($Value, $Message)
        $err = { Should-NotBeSame -Actual $Value -Expected $Value } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Equal $Message
    }

    It "Returns the value on output" {
        $expected = 1
        $expected | Should-NotBeSame 7 | Verify-Equal $expected
    }

    It "Can be called with positional parameters" {
        {
            $obj = New-Object -TypeName PSObject
            Should-NotBeSame $obj $obj
        } | Verify-AssertionFailed
    }
}

