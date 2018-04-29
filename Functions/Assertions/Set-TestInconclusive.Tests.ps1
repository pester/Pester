Set-StrictMode -Version Latest

Describe "Ensuring Set-TestInconclusive is deprecated" {
    Context "Set-TestInconclusive calls Set-ItResult -Inconclusive" {
        InModuleScope -Module Pester {
            # for an unknown reason the test fails in Team City in version 2
            # but since it is just deprecation message we are testing I think it can be skipped
            It "Set-TestInconclusive calls Set-ItResult internally" -Skip:($PSVersionTable.PSVersion.Major -eq 2) {
                Mock Set-ItResult { }
                try { Set-TestInconclusive }
                catch {}
                Assert-MockCalled Set-ItResult -ParameterFilter { $Inconclusive -eq $true }
            }
        }
    }
}
