param ([switch] $PassThru)

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

& "$PSScriptRoot\..\build.ps1"
Import-Module $PSScriptRoot\..\bin\Pester.psd1

$global:PesterPreference = [PesterConfiguration] @{
    Debug = @{
        ShowFullErrors         = $true
        WriteDebugMessages     = $true
        WriteDebugMessagesFrom = "Mock"
        ReturnRawResultObject  = $true
    }
    Output = @{ Verbosity = 'Normal' }
}


i -PassThru:$PassThru {
    b "basic mocking in RSpec Pester" {
        t "running a single mock in one It" {
            $sb = {
                BeforeAll { function f { "real" } }
                Describe 'd1' {
                    It 'i1' {
                        Mock f { "mock" }
                        f
                    }
                }
            }

            $actual = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $actual.Containers[0].Blocks[0].Tests[0].StandardOutput | Verify-Equal "mock"
        }

        t "mock does not leak into the subsequent It" {
            $sb = {
                BeforeAll { function f { "real" } }
                Describe 'd1' {
                    It 'i1' {
                        Mock f { "mock" }
                        f
                    }

                    It 'i2' {
                        f
                    }
                }
            }

            $actual = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $actual.Containers[0].Blocks[0].Tests[0].StandardOutput | Verify-Equal "mock"
            $actual.Containers[0].Blocks[0].Tests[1].StandardOutput | Verify-Equal "real"
        }

        t "mock defined in beforeall is used in every it" {
            $sb = {
                BeforeAll { function f { "real" } }
                Describe 'd1' {
                    BeforeAll {
                        Mock f { "mock" }
                    }

                    It 'i1' {
                        f
                    }

                    It 'i2' {
                        f
                    }
                }
            }

            $actual = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $actual.Containers[0].Blocks[0].Tests[0].StandardOutput | Verify-Equal "mock"
            $actual.Containers[0].Blocks[0].Tests[1].StandardOutput | Verify-Equal "mock"
        }


        t "mock defined in beforeall is counted independently" {
            $sb = {
                BeforeAll { function f { "real" } }
                Describe 'd1' {
                    BeforeAll {
                        Mock f { "mock" }
                    }

                    It 'i1' {
                        f
                        Should -Invoke f -Times 1 -Exactly
                    }

                    It 'i2' {
                        f
                        Should -Invoke f -Times 1 -Exactly
                    }
                }
            }

            $actual = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $actual.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
            $actual.Containers[0].Blocks[0].Tests[1].Passed | Verify-True
        }

        t "mock defined in before all can be counted from all tests with -Describe" {
            $sb = {
                BeforeAll { function f { "real" } }
                Describe 'd1' {
                    BeforeAll {
                        Mock f { "mock" }
                    }

                    It 'i1' {
                        f
                        Should -Invoke f -Times 1 -Exactly
                    }

                    It 'i2' {
                        f
                        Should -Invoke f -Times 2 -Exactly -Scope Describe
                    }
                }
            }

            $actual = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $actual.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
            $actual.Containers[0].Blocks[0].Tests[1].Passed | Verify-True
        }

        t "mock defined in before all can and counted from after all automatically counts all calls in the current block" {
            $sb = {
                BeforeAll { function f { "real" } }
                Describe 'd1' {
                    BeforeAll {
                        Mock f { "mock" }
                    }

                    It 'i1' {
                        f
                    }

                    It 'i2' {
                        f
                    }

                    AfterAll {
                        Should -Invoke f -Times 2 -Exactly
                    }
                }
            }

            $actual = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })
            $actual.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
            $actual.Containers[0].Blocks[0].Tests[1].Passed | Verify-True
        }
    }

    b "taking mocks from all scopes" {
        t "mocks defined in the parent scope can still be used" {
            $sb = {
                BeforeAll { function f { "real" } }
                Describe 'd1' {
                    BeforeAll {
                        Mock f { "mock" }
                    }

                    Describe 'd2' {
                        Describe 'd3' {
                            It 'i1' {
                                f
                            }
                        }
                    }

                    AfterAll {
                        Should -Invoke f -Times 1 -Exactly
                    }
                }
            }

            $actual = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $actual.Containers[0].Blocks[0].Blocks[0].Blocks[0].Tests[0].StandardOutput | Verify-Equal 'mock'
        }
    }

    b "mock filters" {
        t "calling filtered and default mock chooses the correct mock to call" {
            $sb = {
                BeforeAll { function f { "real" } }
                Describe 'd1' {
                    BeforeAll {
                        Mock Get-Variable { "filtered" } -ParameterFilter {
                            $Name -eq 'PSVersionTable' -and $ValueOnly
                        }

                        Mock Get-Variable { "default" }
                    }

                    It 'makes a call to the filtered mock' {
                        Get-Variable -Name PSVersionTable -ValueOnly | Should -Be "filtered"
                    }

                    It 'makes a call to the default mock' {
                        Get-Variable -Name PSVersionTable | Should -Be "default"
                    }
                }
            }

            $actual = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $actual.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
            $actual.Containers[0].Blocks[0].Tests[1].Passed | Verify-True
        }
    }

    b "named mock scopes" {
        t "asserting in scope describe finds all mocks in the nearest describe" {
            $sb = {
                BeforeAll { function a { } }
                Describe 'd-2' {
                    # scope 4
                    Describe "d-1" {
                        # scope 3
                        Describe 'd1' {
                            # scope 2
                            BeforeAll {
                                Mock a { }
                            }

                            It 'i1' {
                                a # call 1
                            }

                            Context "c1" {
                                # scope 1
                                It 'i2' {
                                    a # call 2
                                }

                                It 'i1' {
                                    # scope 0
                                    Should -Invoke a -Exactly 0 -Scope 0
                                    Should -Invoke a -Exactly 0 -Scope It
                                    Should -Invoke a -Exactly 1 -Scope 1
                                    Should -Invoke a -Exactly 1 -Scope Context
                                    Should -Invoke a -Exactly 2 -Scope 2
                                    Should -Invoke a -Exactly 2 -Scope Describe
                                    Should -Invoke a -Exactly 2 -Scope 3
                                    Should -Invoke a -Exactly 2 -Scope 4
                                }
                            }
                        }
                    }
                }
            }

            $actual = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })
            $actual.Containers[0].Blocks[0].Blocks[0].Blocks[0].Blocks[0].Tests[1].Passed | Verify-True
        }
    }

    b "should in mock" {
        t "should will throw even when Should ErrorAction preference is set to Continue and fails the test" {
            $sb = {
                Describe "a" {
                    It "it" {

                        function f ($Name) { "real function" }
                        Mock f -MockWith { "default mock" }
                        Mock f -ParameterFilter { $Name | Should -Be "a" } -MockWith { "mock with filter" }

                        f "b"
                        "won't reach this"
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                Run = @{ ScriptBlock = $sb; PassThru = $true }
                Should = @{ ErrorAction = 'Continue' }
            })

            $t = $r.Containers[0].Blocks[0].Tests[0]
            $t.StandardOutput | Verify-Null # the "won't reach this" should not run because the mock filter will throw before it
            $err = $t.ErrorRecord[0] -split "`n"
            $err[-2] | Verify-Equal "Expected: 'a'"
            $err[-1] | Verify-Equal "But was:  'b'"
        }
    }

    b "splatting on default params" {
        t "should be able to splat whatif" {
            # https://github.com/pester/Pester/issues/1519
            $sb = {
                Describe "a" {
                    It "it" {
                        function Subject {
                            $params = @{
                                Path   = 'c:\temp\nothing'
                                WhatIf = $true
                            }

                            Remove-Item @params
                        }

                        Mock Remove-Item {
                            'This should be called'
                        }

                        Subject

                        Should -Invoke Remove-Item -Exactly 1
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                Run = @{ ScriptBlock = $sb; PassThru = $true }
            })

            $t = $r.Containers[0].Blocks[0].Tests[0]
            $t.StandardOutput | Verify-Equal 'This should be called'
            $t.Result | Verify-Equal "Passed"
        }
    }

    b "cross module mocking and counting" {
        try {
            Get-Module Source, Target | Remove-Module
            New-Module -Name Source -ScriptBlock {

                # this module is the source of the public command
                # we should be able to mock it in a different module
                # in user scope
                # and in this module as well
                function Public {
                    Private
                }

                function Private {
                    "private"
                }

                Set-Alias -Name pub -Value Public

                Export-ModuleMember -Function Public -Alias pub
            } | Import-Module -Force

            New-Module Target {
                # this module is the target we will inject mock into it
                # and check if the call to Public2 is calling the mocked
                # Public function imported from Source
                function Public2 {
                    Public
                }
            } | Import-Module -Force

            t "can mock Private in the same module" {
                $sb = {
                    Describe "a" {
                        It "it" {
                            Mock -ModuleName Source -CommandName Private -MockWith { "mock" }
                            Public
                        }
                    }
                }

                $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                    Run = @{ ScriptBlock = $sb; PassThru = $true }
                })

                $t = $r.Containers[0].Blocks[0].Tests[0]
                $t.StandardOutput | Verify-Equal 'mock'
                $t.Result | Verify-Equal "Passed"
            }

            # we have two modules one is the one that defines the function we are mocking
            # and the other one is using it. To mock the public functions of Source we need to insert
            # mocks into the Target module (because that is the module using them).
            # we also need to ensure that the mock body will still run in the test scope.
            t "can mock Public in a module that is not the module that defines that function" {
                $sb = {
                    Describe "a" {
                        It "it" {
                            Mock -ModuleName Target -CommandName Public -MockWith { "mock" }
                            Public2
                        }
                    }
                }

                $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                    Run = @{ ScriptBlock = $sb; PassThru = $true }
                })

                $t = $r.Containers[0].Blocks[0].Tests[0]
                $t.StandardOutput | Verify-Equal 'mock'
                $t.Result | Verify-Equal "Passed"
            }

            t "can mock Public in a module that is not the module that defines that function and still runs the MockWith in the test scope" {
                $sb = {
                    Describe "a" {
                        It "it" {
                            $mockResult = "mmm"
                            Mock -ModuleName Target -CommandName Public -MockWith { $mockResult }
                            Public2
                        }
                    }
                }

                $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                    Run = @{ ScriptBlock = $sb; PassThru = $true }
                })

                $t = $r.Containers[0].Blocks[0].Tests[0]
                $t.StandardOutput | Verify-Equal 'mmm'
                $t.Result | Verify-Equal "Passed"
            }

            t "can count calls to Public in a module that is not the module that defines that function and still run the MockWith in the test scope" {
                # here we have three session states at play.
                # - The caller session state in which we want to invoke the MockWith, to be able to use variables from the test in the mock body
                # - The target session state in which we will insert the mock, in this case the Target module Session State
                # - And the source session state (or more precisely the Source module) from which we resolve the command, and need to define fully qualified name for it
                #   and it's aliases to point to Source/Public
                #
                # the Should -Invoke part should then find the calls that were made from the Target module, to Target||Public function
                $sb = {
                    Describe "a" {
                        It "it" {
                            $mockResult = "mmm"
                            Mock -ModuleName Target -CommandName Public -MockWith { $mockResult }
                            Public2 | Should -Be "mmm"
                            Should -Invoke Public -ModuleName Target -Exactly 1
                        }
                    }
                }

                $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                    Run = @{ ScriptBlock = $sb; PassThru = $true }
                })

                $t = $r.Containers[0].Blocks[0].Tests[0]
                $t.Result | Verify-Equal "Passed"
            }

            t "can mock Private in a module and then call it from a different module" {
                $sb = {
                    Describe "a" {
                        It "it" {
                            Mock -ModuleName Source -CommandName Private -MockWith { "mock" }
                            Public2 # -> Public -> Private (mocked)
                        }
                    }
                }

                $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                    Run = @{ ScriptBlock = $sb; PassThru = $true }
                })

                $t = $r.Containers[0].Blocks[0].Tests[0]
                $t.StandardOutput | Verify-Equal 'mock'
                $t.Result | Verify-Equal "Passed"
            }

            t "can count calls to Private in a module when called from a different module" {
                $sb = {
                    Describe "a" {
                        It "it" {
                            Mock -ModuleName Source -CommandName Private -MockWith { "mock" }
                            Public2 | Should -Be 'mock'

                            Should -Invoke Private -ModuleName Source
                        }

                        It "cleans up the mock" {
                            Public2 Should -Not -Be 'mock'
                        }
                    }
                }

                $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                    Run = @{ ScriptBlock = $sb; PassThru = $true }
                })

                $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
                $r.Containers[0].Blocks[0].Tests[1].Result | Verify-Equal "Passed"
            }
        }
        finally {
            Get-Module Source, Target | Remove-Module -Force -ErrorAction Ignore
        }
    }

    b "counting verifiable mocks" {
        t "should count mocks correctly when there are multiple behaviors defined in the test" {
            # https://github.com/pester/Pester/issues/1539
            $sb = {
                Context "a" {
                    It "b" {
                        function a {}
                        function b {}

                        Mock a
                        Mock a -ParameterFilter { $true }
                        Mock b -Verifiable

                        a
                        b

                        Should -InvokeVerifiable
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                Run = @{ ScriptBlock = $sb; PassThru = $true }
            })

            $t = $r.Containers[0].Blocks[0].Tests[0]
            $t.Result | Verify-Equal "Passed"
        }

        t "should count mocks correctly when there are multiple behaviors defined in block" {
            # https://github.com/pester/Pester/issues/1539
            $sb = {
                Context "a" {
                    BeforeAll {
                        function a {}
                        function b {}

                        Mock a
                        Mock a -ParameterFilter { $true }
                        Mock b -Verifiable
                    }

                    It "b" {
                        a
                        b

                        Should -InvokeVerifiable
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                Run = @{ ScriptBlock = $sb; PassThru = $true }
            })

            $t = $r.Containers[0].Blocks[0].Tests[0]
            $t.Result | Verify-Equal "Passed"
        }
    }

    b "top-level mocks" {
        t "should allow mock to be defined in top-level BeforeAll" {
            # https://github.com/pester/Pester/issues/1559
            $sb = {
                BeforeAll {
                    Mock Get-Command { "ffff" }
                    Get-Command | Should -Be "ffff"
                }

                Describe "d1" {
                    It "i1" {
                        Get-Command | Should -Be "ffff"
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                Run = @{ ScriptBlock = $sb; PassThru = $true }
            })

            $t = $r.Containers[0].Blocks[0].Tests[0]
            $t.Result | Verify-Equal "Passed"
        }

        t "should count mock in top-level BeforeAll" {
            # https://github.com/pester/Pester/issues/1559
            $sb = {
                BeforeAll {
                    Mock Get-Command { "ffff" }
                    Get-Command | Should -Be "ffff"
                    Should -Invoke Get-Command -Exactly 1
                }

                Describe "d1" {
                    It "i1" {
                        Get-Command | Should -Be "ffff"
                        Should -Invoke Get-Command -Exactly 1
                        Should -Invoke Get-Command -Exactly 1 -Scope Describe
                        Should -Invoke Get-Command -Exactly 2 -Scope 2
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                Run = @{ ScriptBlock = $sb; PassThru = $true }
            })

            $t = $r.Containers[0].Blocks[0].Tests[0]
            $t.Result | Verify-Equal "Passed"
        }


        t "should count verifiable mock in top-level BeforeAll" {
            # https://github.com/pester/Pester/issues/1559
            $sb = {
                BeforeAll {
                    Mock Get-Command { "ffff" } -Verifiable
                    Get-Command | Should -Be "ffff"
                    Should -InvokeVerifiable
                }

                Describe "d1" {
                    It "i1" {
                        Should -InvokeVerifiable
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                Run = @{ ScriptBlock = $sb; PassThru = $true }
            })

            $t = $r.Containers[0].Blocks[0].Tests[0]
            $t.Result | Verify-Equal "Passed"
        }
    }

    b "mocking cmdlets" {
        t "mocking Test-Path" {
            # https://github.com/pester/Pester/issues/1551
            # Test-Path was not always taking from SafeCommands, so cleaning TestDrive
            # failed. This is why we need to be in extra Context, to clean up TestDrive
            # not just tear it down.
            $sb = {
                Describe Do-Something {
                    BeforeAll {
                        function Do-Something { }

                        Mock Test-Path { $true }
                    }

                    Context 'Some block' {
                        It 'does something' {
                            Do-Something
                        }
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                Run = @{ ScriptBlock = $sb; PassThru = $true }
            })

            $t = $r.Containers[0].Blocks[0].Blocks[0].Tests[0]
            $t.Result | Verify-Equal "Passed"
        }
    }

    b "clean up mocks when -ModuleName is used" {
        t "cleans up Mock in the module where it was defined" {
            # when module name is used we should clean up in the module in which we defined the mock
            # command and aliased, and not in the caller scope
            # https://github.com/pester/Pester/issues/1693

            Get-Module m | Remove-Module
            $m = New-Module -Name m {
                # calling 'a' which calls 'f' so we run the mock that is effective
                # inside of this module
                function a () { f }
                function f () { "real" }

                Export-ModuleMember -Function a
            } -PassThru

            $m | Import-Module

            $sb = {
                BeforeAll {
                    Mock f -ModuleName m { "mock" }
                }

                Describe "d1" {
                    It "i1" {
                        # this should mock and then on the end the mock should be teared down
                        # correctly so it is no longer effective in the next test run, when this is
                        # done incorrectly, the alias and mock function remain defined in the module
                        # and the mock hook remains in place. This breaks mock counting in subsequent tests.
                        a | Should -Be "mock"
                    }
                }
            }


            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                Run = @{ ScriptBlock = $sb; PassThru = $true }
            })

            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $command = & ($m) { Get-Command -Name f }

            # this should be function. It should not be alias, because aliases are used for
            # mocking
            $command.CommandType | Verify-Equal "Function"
            # $command.DisplayName
        }
    }
}
