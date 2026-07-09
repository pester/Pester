Set-StrictMode -Version Latest

BeforeAll {
    $PSDefaultParameterValues = @{ 'Should:ErrorAction' = 'Stop' }
}

Describe 'Mock.Global configuration option' {
    It 'defaults to $false' {
        (New-PesterConfiguration).Mock.Global.Value | Should -BeFalse
    }

    It 'makes every mock reach calls from any module or script' {
        # The behavior of global mocks can only be observed from inside a run that has the option
        # enabled, so we drive a nested Pester run with Mock.Global = $true and assert that all of its
        # tests pass. Each 'It' below documents one behavior of a global mock.
        $container = New-PesterContainer -ScriptBlock {
            Describe 'global mocks' {
                BeforeAll {
                    # A module that calls commands from its own session state. A normal mock defined in
                    # the test script scope does not reach these calls; a global mock does.
                    $null = New-Module -Name GlobalMockConsumer -ScriptBlock {
                        function Get-YearFromModule { (Get-Date).Year }
                        function Get-QualifiedYearFromModule { (Microsoft.PowerShell.Utility\Get-Date).Year }
                        function Invoke-BlockedRequest { Invoke-WebRequest -Uri 'http://example.com' }
                        function Read-Path { param($Path) Get-Content -Path $Path }
                        function Get-HiddenItems { Get-ChildItem -Hidden }
                        Export-ModuleMember -Function Get-YearFromModule, Get-QualifiedYearFromModule, Invoke-BlockedRequest, Read-Path, Get-HiddenItems
                    } | Import-Module -PassThru -Force
                }

                AfterAll {
                    Remove-Module GlobalMockConsumer -Force -ErrorAction SilentlyContinue
                }

                It 'reaches calls made from inside another module' {
                    Mock Get-Date { [pscustomobject]@{ Year = 1999 } }
                    Get-YearFromModule | Should -Be 1999
                }

                It 'reaches module-qualified calls' {
                    Mock Get-Date { [pscustomobject]@{ Year = 1999 } }
                    Get-QualifiedYearFromModule | Should -Be 1999
                }

                It 'records the calls, so Should -Invoke works without -ModuleName' {
                    Mock Get-Date { [pscustomobject]@{ Year = 1999 } }
                    $null = Get-YearFromModule
                    $null = Get-YearFromModule
                    Should -Invoke Get-Date -Exactly -Times 2
                }

                It 'uses -ModuleName only as a resolve hint, not to scope the mock' {
                    # a bogus module name is ignored, the command resolves in the caller scope anyway
                    Mock Get-Date { [pscustomobject]@{ Year = 1999 } } -ModuleName 'ThisModuleDoesNotExist'
                    Get-YearFromModule | Should -Be 1999
                }

                It 'a throwing mock blocks the command everywhere and still records the call' {
                    Mock Invoke-WebRequest { throw 'blocked' }
                    { Invoke-BlockedRequest } | Should -Throw '*blocked*'
                    Should -Invoke Invoke-WebRequest -Exactly -Times 1
                }

                It 'a parameter filter blocks only matching calls, others fall through' {
                    Mock Get-Content { 'allowed-content' } -ParameterFilter { $Path -like '*allowed*' }
                    Mock Get-Content { throw 'blocked' } -ParameterFilter { $Path -notlike '*allowed*' }

                    Read-Path -Path 'C:\allowed\file.txt' | Should -Be 'allowed-content'
                    { Read-Path -Path 'C:\secret\file.txt' } | Should -Throw '*blocked*'
                }

                It 'preserves the original cmdlet dynamic parameters' {
                    # Get-ChildItem -Hidden relies on the FileSystem provider's dynamic parameters. The
                    # global hook must not hide them when resolving the command to build the mock.
                    Mock Get-ChildItem { 'mocked' }
                    Get-HiddenItems | Should -Be 'mocked'
                }

                It 'does not affect commands Pester calls internally through SafeCommands' {
                    # Pester dispatches its internal commands through $SafeCommands (captured CommandInfo
                    # invoked with the call operator), which does not go through command lookup. A global
                    # mock of a command Pester uses internally must not break Pester itself.
                    Mock Get-Command { throw 'blocked' }
                    { Get-Command Get-Date } | Should -Throw '*blocked*'
                }
            }

            Describe 'global mock cleanup' {
                # Runs after the block above. If a global mock leaked past its defining test, Get-Date
                # would still be mocked here.
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
        }

        $configuration = New-PesterConfiguration
        $configuration.Run.Container = $container
        $configuration.Run.PassThru = $true
        $configuration.Output.Verbosity = 'None'
        $configuration.Mock.Global = $true

        $result = Invoke-Pester -Configuration $configuration
        $result.Result | Should -Be 'Passed'
        $result.FailedCount | Should -Be 0
        $result.PassedCount | Should -BeGreaterThan 0
    }
}
