Set-StrictMode -Version Latest

BeforeAll {
    $PSDefaultParameterValues = @{ 'Should:ErrorAction' = 'Stop' }
}

Describe 'Mock -Global' {
    BeforeAll {
        # A module that calls commands from its own session state. A normal mock defined in the test
        # script scope does not reach these calls, which is what -Global changes.
        $null = New-Module -Name GlobalMockConsumer -ScriptBlock {
            function Get-YearFromModule { (Get-Date).Year }
            function Get-QualifiedYearFromModule { (Microsoft.PowerShell.Utility\Get-Date).Year }
            Export-ModuleMember -Function Get-YearFromModule, Get-QualifiedYearFromModule
        } | Import-Module -PassThru -Force
    }

    AfterAll {
        Remove-Module GlobalMockConsumer -Force -ErrorAction SilentlyContinue
    }

    It 'a normal mock does not reach calls made from inside another module' {
        Mock Get-Date { [pscustomobject]@{ Year = 1999 } }
        Get-YearFromModule | Should -Not -Be 1999
    }

    It 'a -Global mock reaches calls made from inside another module' {
        Mock Get-Date { [pscustomobject]@{ Year = 1999 } } -Global
        Get-YearFromModule | Should -Be 1999
    }

    It 'a -Global mock reaches module-qualified calls' {
        Mock Get-Date { [pscustomobject]@{ Year = 1999 } } -Global
        Get-QualifiedYearFromModule | Should -Be 1999
    }

    It 'records the calls, so Should -Invoke works without -ModuleName' {
        Mock Get-Date { [pscustomobject]@{ Year = 1999 } } -Global
        $null = Get-YearFromModule
        $null = Get-YearFromModule
        Should -Invoke Get-Date -Exactly -Times 2
    }

    It 'ignores -ModuleName when -Global is used' {
        Mock Get-Date { [pscustomobject]@{ Year = 1999 } } -Global -ModuleName 'ThisModuleDoesNotExist'
        Get-YearFromModule | Should -Be 1999
    }
}

Describe 'Mock -Global cleanup' {
    # This block runs after the -Global block above. If a global mock leaked past its defining test,
    # Get-Date would still be mocked here and the year would be 1999.
    BeforeAll {
        $null = New-Module -Name GlobalMockConsumerCleanup -ScriptBlock {
            function Get-YearAfterCleanup { (Get-Date).Year }
            Export-ModuleMember -Function Get-YearAfterCleanup
        } | Import-Module -PassThru -Force
    }

    AfterAll {
        Remove-Module GlobalMockConsumerCleanup -Force -ErrorAction SilentlyContinue
    }

    It 'removes the global mock once the defining test ends' {
        Get-YearAfterCleanup | Should -BeGreaterThan 2000
    }
}

Describe 'Mock -Throw' {
    BeforeAll {
        $null = New-Module -Name ThrowMockConsumer -ScriptBlock {
            function Invoke-BlockedRequest { Invoke-WebRequest -Uri 'http://example.com' }
            function Read-Path { param($Path) Get-Content -Path $Path }
            Export-ModuleMember -Function Invoke-BlockedRequest, Read-Path
        } | Import-Module -PassThru -Force
    }

    AfterAll {
        Remove-Module ThrowMockConsumer -Force -ErrorAction SilentlyContinue
    }

    It 'blocks the command when it is called from another module' {
        Mock Invoke-WebRequest -Throw
        { Invoke-BlockedRequest } | Should -Throw '*blocked by a global Pester mock*'
    }

    It 'records the blocked call, so Should -Invoke works' {
        Mock Invoke-WebRequest -Throw
        { Invoke-BlockedRequest } | Should -Throw
        Should -Invoke Invoke-WebRequest -Exactly -Times 1
    }

    It 'throws only for calls that match the parameter filter, others fall through' {
        Mock Get-Content { 'allowed-content' } -Global -ParameterFilter { $Path -like '*allowed*' }
        Mock Get-Content -Throw -ParameterFilter { $Path -notlike '*allowed*' }

        Read-Path -Path 'C:\allowed\file.txt' | Should -Be 'allowed-content'
        { Read-Path -Path 'C:\secret\file.txt' } | Should -Throw '*blocked by a global Pester mock*'
    }

    It 'cannot be combined with -MockWith' {
        { Mock Get-Date -Throw -MockWith { 1 } } | Should -Throw '*-Throw and -MockWith*'
    }
}

Describe 'Mock.Global configuration option' {
    It 'defaults to $false' {
        (New-PesterConfiguration).Mock.Global.Value | Should -BeFalse
    }

    It 'makes every mock global and ignores -ModuleName' {
        $container = New-PesterContainer -ScriptBlock {
            Describe 'forced global' {
                BeforeAll {
                    $null = New-Module -Name ConfigForcedConsumer -ScriptBlock {
                        function Get-ForcedYear { (Get-Date).Year }
                        Export-ModuleMember -Function Get-ForcedYear
                    } | Import-Module -PassThru -Force
                }

                AfterAll {
                    Remove-Module ConfigForcedConsumer -Force -ErrorAction SilentlyContinue
                }

                It 'a plain mock reaches another module because the option is on' {
                    # note: no -Global and a bogus -ModuleName, the option forces it global anyway
                    Mock Get-Date { [pscustomobject]@{ Year = 1234 } } -ModuleName 'Nope'
                    Get-ForcedYear | Should -Be 1234
                }
            }
        }

        $configuration = New-PesterConfiguration
        $configuration.Run.Container = $container
        $configuration.Run.PassThru = $true
        $configuration.Output.Verbosity = 'None'
        $configuration.Mock.Global = $true

        $result = Invoke-Pester -Configuration $configuration
        $result.Result | Should -Be 'Passed'
        $result.PassedCount | Should -Be 1
        $result.FailedCount | Should -Be 0
    }
}

Describe 'Global mocks and Pester internals' {
    It 'does not affect commands Pester calls internally through SafeCommands' {
        # Pester dispatches its internal commands through $SafeCommands, which are captured CommandInfo
        # objects invoked with the call operator. That path does not go through the engine-level command
        # lookup, so blocking a command by name globally must not break Pester itself.
        Mock Get-Command -Throw

        # Setting up this mock makes Pester resolve Get-ChildItem internally (via SafeCommands). If the
        # global block leaked into Pester internals, this line would throw.
        Mock Get-ChildItem { 'mocked' } -Global
        Get-ChildItem | Should -Be 'mocked'

        # A by-name call from the test scope is still blocked.
        { Get-Command Get-Date } | Should -Throw '*blocked by a global Pester mock*'
    }
}
