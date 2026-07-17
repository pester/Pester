Set-StrictMode -Version Latest

BeforeAll {
    $PSDefaultParameterValues = @{ 'Should:ErrorAction' = 'Stop' }
}

Describe 'Mock.Global configuration option' {
    It 'defaults to $false' {
        (New-PesterConfiguration).Mock.Global.Value | Should-BeFalse
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
                    Get-YearFromModule | Should-Be 1999
                }

                It 'reaches module-qualified calls' {
                    Mock Get-Date { [pscustomobject]@{ Year = 1999 } }
                    Get-QualifiedYearFromModule | Should-Be 1999
                }

                It 'records the calls, so Should -Invoke works without -ModuleName' {
                    Mock Get-Date { [pscustomobject]@{ Year = 1999 } }
                    $null = Get-YearFromModule
                    $null = Get-YearFromModule
                    Should-Invoke Get-Date -Exactly -Times 2
                }

                It 'uses -ModuleName only as a resolve hint, not to scope the mock' {
                    # a bogus module name is ignored, the command resolves in the caller scope anyway
                    Mock Get-Date { [pscustomobject]@{ Year = 1999 } } -ModuleName 'ThisModuleDoesNotExist'
                    Get-YearFromModule | Should-Be 1999
                }

                It 'a throwing mock blocks the command everywhere and still records the call' {
                    Mock Invoke-WebRequest { throw 'blocked' }
                    { Invoke-BlockedRequest } | Should-Throw -ExceptionMessage '*blocked*'
                    Should-Invoke Invoke-WebRequest -Exactly -Times 1
                }

                It 'a parameter filter blocks only matching calls, others fall through' {
                    Mock Get-Content { 'allowed-content' } -ParameterFilter { $Path -like '*allowed*' }
                    Mock Get-Content { throw 'blocked' } -ParameterFilter { $Path -notlike '*allowed*' }

                    Read-Path -Path 'C:\allowed\file.txt' | Should-BeString 'allowed-content'
                    { Read-Path -Path 'C:\secret\file.txt' } | Should-Throw -ExceptionMessage '*blocked*'
                }

                It 'preserves the original cmdlet dynamic parameters' {
                    # Get-ChildItem -Hidden relies on the FileSystem provider's dynamic parameters. The
                    # global hook must not hide them when resolving the command to build the mock.
                    Mock Get-ChildItem { 'mocked' }
                    Get-HiddenItems | Should-BeString 'mocked'
                }

                It 'does not affect commands Pester calls internally through SafeCommands' {
                    # Pester dispatches its internal commands through $SafeCommands (captured CommandInfo
                    # invoked with the call operator), which does not go through command lookup. A global
                    # mock of a command Pester uses internally must not break Pester itself.
                    Mock Get-Command { throw 'blocked' }
                    { Get-Command Get-Date } | Should-Throw -ExceptionMessage '*blocked*'
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
                    Get-YearAfterCleanup | Should-BeGreaterThan 2000
                }
            }
        }

        $configuration = New-PesterConfiguration
        $configuration.Run.Container = $container
        $configuration.Run.PassThru = $true
        $configuration.Output.Verbosity = 'None'
        $configuration.Mock.Global = $true

        $result = Invoke-Pester -Configuration $configuration
        $result.Result | Should-BeString 'Passed'
        $result.FailedCount | Should-Be 0
        $result.PassedCount | Should-BeGreaterThan 0
    }
}

Describe 'Global mock hook lifecycle' {
    It 'a nested Pester run does not clobber the outer run''s global mocks' {
        # The global mock hook is runspace-wide. A nested Invoke-Pester (Pester-in-Pester) must not
        # overwrite or tear down the outer run's global mocks. The outer run below defines a global mock,
        # runs an inner Pester run that defines its own global mock for the same command, and then checks
        # that its own mock is still in effect after the inner run finished.
        $container = New-PesterContainer -ScriptBlock {
            Describe 'outer' {
                It 'keeps its own global mock across a nested run' {
                    Mock Get-Date { [pscustomobject]@{ Year = 1111 } }
                    (Get-Date).Year | Should-Be 1111

                    $inner = New-PesterContainer -ScriptBlock {
                        Describe 'inner' {
                            It 'has its own global mock' {
                                Mock Get-Date { [pscustomobject]@{ Year = 2222 } }
                                (Get-Date).Year | Should-Be 2222
                            }
                        }
                    }
                    $innerConfig = New-PesterConfiguration
                    $innerConfig.Run.Container = $inner
                    $innerConfig.Run.PassThru = $true
                    $innerConfig.Output.Verbosity = 'None'
                    $innerConfig.Mock.Global = $true
                    $innerResult = Invoke-Pester -Configuration $innerConfig
                    $innerResult.FailedCount | Should-Be 0
                    $innerResult.PassedCount | Should-Be 1

                    # the outer run's global mock must still be in effect after the nested run
                    (Get-Date).Year | Should-Be 1111
                }
            }
        }

        $configuration = New-PesterConfiguration
        $configuration.Run.Container = $container
        $configuration.Run.PassThru = $true
        $configuration.Output.Verbosity = 'None'
        $configuration.Mock.Global = $true

        $result = Invoke-Pester -Configuration $configuration
        $result.Result | Should-BeString 'Passed'
        $result.FailedCount | Should-Be 0
    }

    It 'a nested Pester run does not inherit the outer run''s global mocks' {
        # Full isolation via the per-run nonce: a global mock defined in the outer run must not leak into a
        # nested run through its script-scope bootstrap alias. The inner run below does not mock Get-Date,
        # so it must see the real command, not the outer run's fake value.
        $container = New-PesterContainer -ScriptBlock {
            Describe 'outer' {
                It 'runs a nested run that does not mock the command' {
                    Mock Get-Date { [pscustomobject]@{ Year = 1111 } }
                    (Get-Date).Year | Should-Be 1111

                    $inner = New-PesterContainer -ScriptBlock {
                        Describe 'inner' {
                            It 'sees the real command, not the outer global mock' {
                                # Get-Date is not mocked in this run; the outer run's global mock must not
                                # leak in, so we must get a real date (not the fake 1111 the outer set).
                                (Get-Date).Year | Should-NotBe 1111
                            }
                        }
                    }
                    $innerConfig = New-PesterConfiguration
                    $innerConfig.Run.Container = $inner
                    $innerConfig.Run.PassThru = $true
                    $innerConfig.Output.Verbosity = 'None'
                    $innerConfig.Mock.Global = $true
                    $innerResult = Invoke-Pester -Configuration $innerConfig
                    $innerResult.FailedCount | Should-Be 0
                    $innerResult.PassedCount | Should-Be 1

                    # the outer run's global mock must still be in effect after the nested run
                    (Get-Date).Year | Should-Be 1111
                }
            }
        }

        $configuration = New-PesterConfiguration
        $configuration.Run.Container = $container
        $configuration.Run.PassThru = $true
        $configuration.Output.Verbosity = 'None'
        $configuration.Mock.Global = $true

        $result = Invoke-Pester -Configuration $configuration
        $result.Result | Should-BeString 'Passed'
        $result.FailedCount | Should-Be 0
    }

    It 'a fresh top-level run clears a global mock hook left armed by a previous run' {
        # An interrupted run (for example Ctrl+C during a global mock) can leave the runspace-wide hook
        # armed, because its teardown never ran. A new top-level Invoke-Pester must reset it. This can only
        # be observed at the top level (a nested run snapshots/restores instead), so we use a child process:
        # arm the hook by hand, run a trivial top-level Pester run, and confirm the hook was cleared.
        $modulePath = (Get-Module -Name Pester | Select-Object -First 1).Path
        $modulePath | Should-NotBeEmptyString

        $childScript = {
            Import-Module $env:PESTER_MODULE_PATH_FOR_TEST -Force

            # simulate a global mock left behind by an interrupted run
            [Pester.GlobalMockHook]::Register('LeftoverGlobalMock', (Get-Command -Name Get-Date))
            $ec = $ExecutionContext.SessionState.InvokeCommand
            $ec.PreCommandLookupAction = [Delegate]::Combine($ec.PreCommandLookupAction, [Pester.GlobalMockHook]::Handler)
            $before = [Pester.GlobalMockHook]::Count

            $container = New-PesterContainer -ScriptBlock {
                Describe 'trivial' { It 'passes' { 1 | Should-Be 1 } }
            }
            $c = New-PesterConfiguration
            $c.Run.Container = $container
            $c.Run.PassThru = $true
            $c.Output.Verbosity = 'None'
            $r = Invoke-Pester -Configuration $c

            $after = [Pester.GlobalMockHook]::Count
            "BEFORE=$before AFTER=$after RESULT=$($r.Result)"
        }

        $env:PESTER_MODULE_PATH_FOR_TEST = $modulePath
        try {
            $exe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
            $output = (& $exe -NoProfile -Command $childScript 2>&1) -join "`n"
        }
        finally {
            $env:PESTER_MODULE_PATH_FOR_TEST = $null
        }

        # the hook was armed before the run (BEFORE=1) and cleared by the fresh top-level run (AFTER=0)
        $output | Should-MatchString 'BEFORE=1'
        $output | Should-MatchString 'AFTER=0'
        $output | Should-MatchString 'RESULT=Passed'
    }
}
