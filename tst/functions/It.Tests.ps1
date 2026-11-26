Set-StrictMode -Version Latest

Describe 'Testing It' {
    It 'Throws when missing name' {
        { It {

            'something'
            }
        } | Should -Throw -ExpectedMessage 'Test name has multiple lines and no test scriptblock is provided*'
    }

    It 'Throws when missing scriptblock' {
        { It 'runs a test'
            {
                # This scriptblock is a new statement as scriptblock didn't start on It-line nor used a backtick
            }
        } | Should -Throw -ExpectedMessage 'No test scriptblock is provided*'
    }

    It 'Throws when provided unbound scriptblock' {
        # Unbound scriptblocks would execute in Pester's internal module state
        { It 'i' -Test ([scriptblock]::Create('')) } | Should -Throw -ExpectedMessage 'Unbound scriptblock*'
    }
}

Describe 'Skip -Because' {
    It 'records the reason on the result' {
        $sb = { Describe 'd' { It 'i' -Skip -Because 'the API is down' { } } }
        $c = New-PesterConfiguration
        $c.Run.ScriptBlock = $sb
        $c.Run.PassThru = $true
        $c.Output.Verbosity = 'None'
        $r = Invoke-Pester -Configuration $c

        $r.Tests[0].Result | Should -Be 'Skipped'
        $r.Tests[0].Reason | Should -Be 'the API is down'
    }

    It 'leaves the reason empty when -Because is not used' {
        $sb = { Describe 'd' { It 'i' -Skip { } } }
        $c = New-PesterConfiguration
        $c.Run.ScriptBlock = $sb
        $c.Run.PassThru = $true
        $c.Output.Verbosity = 'None'
        $r = Invoke-Pester -Configuration $c

        $r.Tests[0].Result | Should -Be 'Skipped'
        $r.Tests[0].Reason | Should -BeNullOrEmpty
    }

    It 'applies the reason from a skipped Describe to the tests inside it' {
        $sb = { Describe 'd' -Skip -Because 'needs Azure' { It 'i' { } } }
        $c = New-PesterConfiguration
        $c.Run.ScriptBlock = $sb
        $c.Run.PassThru = $true
        $c.Output.Verbosity = 'None'
        $r = Invoke-Pester -Configuration $c

        $r.Tests[0].Result | Should -Be 'Skipped'
        $r.Tests[0].Reason | Should -Be 'needs Azure'
    }

    It 'applies the reason from a skipped Context to the tests inside it' {
        $sb = { Describe 'd' { Context 'c' -Skip -Because 'needs Azure' { It 'i' { } } } }
        $c = New-PesterConfiguration
        $c.Run.ScriptBlock = $sb
        $c.Run.PassThru = $true
        $c.Output.Verbosity = 'None'
        $r = Invoke-Pester -Configuration $c

        $r.Tests[0].Result | Should -Be 'Skipped'
        $r.Tests[0].Reason | Should -Be 'needs Azure'
    }
}
