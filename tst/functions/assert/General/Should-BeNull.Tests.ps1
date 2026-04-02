Set-StrictMode -Version Latest

Describe "Should-BeNull" {
    It "Given `$null it passes" {
        $null | Should-BeNull
    }

    It "Given an objects it fails" {
        { 1 | Should-BeNull } | Verify-AssertionFailed
    }

    It "Given empty array piped it passes (void function output is empty array)" {
        # When a function returns no output, PowerShell sends @() through the pipeline.
        # Should-BeNull treats this as $null since "no output" is effectively null.
        # See https://github.com/pester/Pester/issues/2555
        @() | Should-BeNull
    }

    It "Given empty array by parameter it fails" {
        { Should-BeNull -Actual @() } | Verify-AssertionFailed
    }

    It "Returns the given value" {
        $null | Should-BeNull | Verify-Null
    }

    It "Can be called with positional parameters (1)" {
        { Should-BeNull 1 } | Verify-AssertionFailed
    }

    It "Can be called with positional parameters (@())" {
        { Should-BeNull @() } | Verify-AssertionFailed
    }
}
