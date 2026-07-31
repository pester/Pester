Set-StrictMode -Version Latest

Describe "Should-NotHaveType" {
    It "Given value of expected type it fails" {
        { 1 | Should-NotHaveType ([int]) } | Verify-AssertionFailed
    }

    It "Given an object of different type it passes" {
        1 | Should-NotHaveType ([string])
    }

    It "Given a value without the expected custom PSTypeName it passes" {
        $actual = [PSCustomObject]@{ PSTypeName = 'MyApp.Person'; Name = 'Jane' }
        $actual | Should-NotHaveType 'MyApp.Animal'
    }

    It "Given a value with a matching custom PSTypeName it fails" {
        $actual = [PSCustomObject]@{ PSTypeName = 'MyApp.Person'; Name = 'Jane' }
        $err = { $actual | Should-NotHaveType 'MyApp.Person' } | Verify-AssertionFailed
        $err.Exception.Message | Verify-Like "*Expected value to be of different type or PSTypeName than*MyApp.Person*"
    }

    It "Can be called with positional parameters" {
        { Should-NotHaveType ([int]) 1 } | Verify-AssertionFailed
    }
}
