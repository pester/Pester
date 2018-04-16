Set-StrictMode -Version Latest

Describe "Ensuring Set-TestInconclusive is deprecated" {
    Context "Set-TestInconclusive calls Set-ItResult -Inconclusive" {
        InModuleScope -Module Pester {
            Mock Set-ItResult { } -ParameterFilter { $Inconclusive -eq $true }
            It "Set-TestInconclusive calls Set-ItResult internally" {
                try { Set-TestInconclusive }
                catch {}
                Assert-MockCalled Set-ItResult
            }
        }
    }
}
