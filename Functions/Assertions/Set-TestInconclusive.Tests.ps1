Set-StrictMode -Version Latest

Describe "Ensuring Set-TestInconclusive is deprecated" {
    Context "Set-TestInconclusive calls Set-ItResult -Inconclusive" {
        InModuleScope -Module Pester {
            It "Set-TestInconclusive calls Set-ItResult internally" {
                Mock Set-ItResult { }
                try { Set-TestInconclusive }
                catch {}
                Assert-MockCalled Set-ItResult -ParameterFilter { $Inconclusive -eq $true }
            }
        }
    }
}
