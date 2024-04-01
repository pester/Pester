Describe "Assert-True" {
        It "Passes when given `$true" {
            $true | Assert-True
        }

        It "Passes when given truthy" -TestCases @(
            @{ Actual = 1 }
            @{ Actual = "text" }
            @{ Actual = New-Object -TypeName PSObject }
            @{ Actual = 1,2 }
        ) {
            param($Actual)
            Assert-True -Actual $Actual
        }

    It "Fails with custom message" {
            $error = { $null | Assert-True -CustomMessage "<actual> is not true" } | Verify-AssertionFailed
            $error.Exception.Message | Verify-Equal "`$null is not true"
    }

    Context "Validate messages" {
        It "Given value that is not `$true it returns expected message '<message>'" -TestCases @(
            @{ Actual = $false ; Message = "Expected bool '`$false' to be bool '`$true' or truthy value."},
            @{ Actual = 0 ; Message = "Expected int '0' to be bool '`$true' or truthy value."}
        ) {
            param($Actual, $Message)
            $error = { Assert-True -Actual $Actual } | Verify-AssertionFailed
            $error.Exception.Message | Verify-Equal $Message
        }
    }

    It "Returns the value on output" {
        $expected = $true
        $expected | Assert-True | Verify-Equal $expected
    }

    It "Can be called with positional parameters" {
        { Assert-True $false } | Verify-AssertionFailed
    }
}