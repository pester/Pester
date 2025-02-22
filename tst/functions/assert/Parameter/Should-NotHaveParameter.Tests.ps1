Set-StrictMode -Version Latest

Describe "Should-HaveParameter" {
    It "Passes when function does not have a parameter" {
        function f () { }

        Get-Command f | Should-NotHaveParameter a
    }

    It "Fails when function has a parameter" {
        function f ($a) { }

        { Get-Command f | Should-NotHaveParameter a } | Verify-Throw
    }
}
