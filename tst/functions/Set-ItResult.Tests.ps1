Set-StrictMode -Version Latest

Describe "Testing Set-ItResult" {
    It "This test should be inconclusive" {
        try {
            Set-ItResult -Inconclusive -Because "we are setting it to inconclusive"
        }
        catch {
            $_.FullyQualifiedErrorID | Should -Be "PesterTestInconclusive"
        }
    }

    It "This test should be skipped" {
        try {
            Set-ItResult -Skipped -Because "we are forcing it to skip"
        }
        catch {
            $_.FullyQualifiedErrorID | Should -Be "PesterTestSkipped"
        }
    }

    It "Set-ItResult appends the -Because reason to the message" {
        try {
            Set-ItResult -Skipped -Because "we are forcing it to skip"
        }
        catch {
            $_.Exception.Message | Should -Be "is skipped, because we are forcing it to skip"
        }
    }

    It "Set-ItResult can be called without -Because" {
        try {
            Set-ItResult -Skipped
        }
        catch {
            $_.FullyQualifiedErrorID | Should -Be "PesterTestSkipped"
        }
    }

    It "Set-ItResult has to have a switch indicating what to set it to" {
        { Set-ItResult -Because "testing with no switch" } | Should -Throw -Because "the expected state is not selected"
    }

    It "Set-ItResult cannot be called with two states requested" {
        { Set-ItResult -Inconclusive -Skipped } | Should -Throw -Because "two states are requested"
    }
}


Describe 'Set-ItResult reason' {
    # .Reason holds the reason on its own, not the sentence Set-ItResult throws
    It 'records the reason when skipping' {
        $sb = { Describe 'd' { It 'i' { Set-ItResult -Skipped -Because 'not on this platform' } } }
        $c = New-PesterConfiguration
        $c.Run.ScriptBlock = $sb
        $c.Run.PassThru = $true
        $c.Output.Verbosity = 'None'
        $r = Invoke-Pester -Configuration $c

        $r.Tests[0].Result | Should -Be 'Skipped'
        $r.Tests[0].Reason | Should -Be 'not on this platform'
    }

    It 'records the reason when inconclusive' {
        $sb = { Describe 'd' { It 'i' { Set-ItResult -Inconclusive -Because 'flaky upstream' } } }
        $c = New-PesterConfiguration
        $c.Run.ScriptBlock = $sb
        $c.Run.PassThru = $true
        $c.Output.Verbosity = 'None'
        $r = Invoke-Pester -Configuration $c

        $r.Tests[0].Result | Should -Be 'Inconclusive'
        $r.Tests[0].Reason | Should -Be 'flaky upstream'
    }
}
