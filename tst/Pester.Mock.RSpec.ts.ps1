param ([switch] $PassThru)

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

& "$PSScriptRoot\..\build.ps1"
Import-Module $PSScriptRoot\..\bin\Pester.psd1

$global:PesterPreference = [PesterConfiguration] @{
    Debug  = @{
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

        t "asserting in scope describe finds all mocks in the nearest describe even when it is more than 2 levels away" {
            # https://github.com/pester/Pester/issues/1833
            # there is special logic that handles the first two levels in easy way,
            # the next levels were off by one
            $sb = {
                Describe 'd2' {
                    # scope 5
                    BeforeAll {
                        function a { }
                        Mock a {}

                        # calling it 3 times, this should not be reached
                        # we should search only till Describe that is nearest
                        # to the test, which is Describe d1
                        a
                        a
                        a
                    }
                    Describe 'd1' {
                        # scope 4
                        BeforeAll {
                            a
                        }

                        Context 'c3' {
                            # scope 3

                            Context 'c2' {
                                # scope 2

                                Context 'c1' {
                                    # scope 1

                                    It 'i1' {
                                        # scope 0

                                        Should -Invoke a -Exactly 0 -Scope 0
                                        # checking by name
                                        Should -Invoke a -Exactly 1 -Scope Describe
                                        # double checking by scope number
                                        Should -Invoke a -Exactly 1 -Scope 4

                                        # make sure we would fail if we searched too low or too high
                                        Should -Invoke a -Exactly 0 -Scope 3
                                        Should -Invoke a -Exactly (3 + 1) -Scope 5
                                    }
                                }
                            }
                        }
                    }
                }
            }

            $actual = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })
            $actual.Containers[0].Blocks[0].Blocks[0].Blocks[0].Blocks[0].Blocks[0].Tests[0].Passed | Verify-True
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
                    Run    = @{ ScriptBlock = $sb; PassThru = $true }
                    Should = @{ ErrorAction = 'Continue' }
                })

            $t = $r.Containers[0].Blocks[0].Tests[0]
            $t.StandardOutput | Verify-Null # the "won't reach this" should not run because the mock filter will throw before it
            $err = $t.ErrorRecord[0] -split "`n"
            $err[-3] | Verify-Equal "Expected: 'a'"
            $err[-2] | Verify-Equal "But was:  'b'"
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

    b "parameter filter conflicting arguments" {
        t "Should -Invoke parameter filter should not use 'arguments' name internally to avoid conflict" {
            # https://github.com/pester/Pester/issues/1819
            $sb = {
                Context "a" {
                    It "b" {
                        function a ($Arguments) {}

                        Mock a

                        a -Arguments @{ Name = "Jakub" }

                        Should -Invoke a -ParameterFilter { "Jakub" -eq $Arguments.Name }
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

    b "Mocking function with custom class attribute" {
        t "generating parametrized tests from foreach without external id" {
            if ($PSVersionTable.PSVersion.Major -le 4) {
                return
            }

            # https://github.com/pester/Pester/issues/1772
            # there is using, it needs to be in a separate file so we can skip it on <PS5
            $result = Invoke-Pester $PSScriptRoot/Pester.Mock.ClassMetadata.ps1 -PassThru

            $result.Containers[0].Blocks[0].ErrorRecord | Verify-Null
            $result.Containers[0].Blocks[0].Tests.Count | Verify-Equal 2
            $result.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
        }
    }

    b "Mocking across modules" {
        t "Mock defined in module is not called when calling from script" {
            $sb = {
                BeforeAll {
                    Get-Module m | Remove-Module
                    New-Module m -ScriptBlock {
                        function f ($a) { "real in module m" }
                    } | Import-Module
                }

                Describe "d" {
                    It "i" {
                        Mock f -ModuleName m { "mock in m" }

                        # called in script, invokes real function
                        f | Should -Be "real in module m"

                        Should -Invoke f -ModuleName m -Exactly 0
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                    Run = @{ ScriptBlock = $sb; PassThru = $true }
                })

            $t = $r.Containers[0].Blocks[0].Tests[0]
            $t.Result | Verify-Equal "Passed"
        }

        t "Mock defined in module is called when calling from that module" {
            $sb = {
                BeforeAll {
                    Get-Module m | Remove-Module
                    New-Module m -ScriptBlock {
                        function f ($a) { "real in module m" }
                    } | Import-Module
                }

                Describe "d" {
                    It "i" {
                        Mock f -ModuleName m { "mock in module m" }

                        # called in script, invokes real function
                        & (Get-Module m ) { f } | Should -Be "mock in module m"

                        Should -Invoke f -ModuleName m -Exactly 1
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                    Run = @{ ScriptBlock = $sb; PassThru = $true }
                })

            $t = $r.Containers[0].Blocks[0].Tests[0]
            $t.Result | Verify-Equal "Passed"
        }

        t "Mock defined in module is called when public function invokes the mocked function in that module" {
            $sb = {
                BeforeAll {
                    Get-Module m, n | Remove-Module
                    New-Module m -ScriptBlock {
                        function f ($a) { "real in module m" }
                    } | Import-Module

                    New-Module n -ScriptBlock {
                        # n can call f that is exported from m, but it calls it from within
                        # module n, so the mock needs to be effective in n
                        function g () { f }
                    } | Import-Module
                }

                Describe "d" {
                    It "i" {
                        Mock f -ModuleName n { "mock in module n" }

                        # this mock in m is ignored
                        Mock f -ModuleName m { "mock in module m" }

                        # this mock in script is ignored
                        Mock f { "mock in script" }


                        # called in script, but invokes function in module n
                        g | Should -Be "mock in module n"

                        Should -Invoke f -ModuleName n -Exactly 1
                        Should -Invoke f -ModuleName m -Exactly 0
                        Should -Invoke f -Exactly 0
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                    Run = @{ ScriptBlock = $sb; PassThru = $true }
                })

            $t = $r.Containers[0].Blocks[0].Tests[0]
            $t.Result | Verify-Equal "Passed"
        }

        t "Mock defined in module falls back to script default behavior when no default behavior is defined in the module" {
            $sb = {
                BeforeAll {
                    Get-Module m | Remove-Module
                    New-Module m -ScriptBlock {
                        function f ($a) { "real in module m" }

                        function g () { f }
                    } | Import-Module
                }

                Describe "d" {
                    It "i" {
                        # we fallback to this from the module when no filtered mock is matched there
                        # but we don't fallback to it when we don't have any mock in the module, because
                        # there is no hook
                        Mock f { "mock in script" }
                        Mock f -ModuleName m { "mock in module" } -ParameterFilter { $false }

                        g | Should -Be "mock in script"

                        Should -Invoke f -Exactly 1
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

    b "Mock cleanup" {
        t "Invoke-Pester cleans up orphaned mock hooks and aliases in modules" {

            # define mock like functions in third party module
            Get-Module m | Remove-Module
            New-Module m -ScriptBlock {
                function PesterMock_aaa () { }
                Set-Alias -Name aaa -Value PesterMock_aaa

                Export-ModuleMember -Function ""
            } | Import-Module

            # in caller scope
            function PesterMock_bbb () { }
            Set-Alias -Name bbb -Value PesterMock_bbb

            # and in Pester module
            . (Get-Module Pester) {
                function PesterMock_ccc () { }
                Set-Alias -Name aaa -Value PesterMock_aaa
            }

            # just trigger empty run to get cleanup
            Invoke-Pester -Configuration ([PesterConfiguration]@{
                    Run = @{ ScriptBlock = {}; PassThru = $true }
                })

            $moduleCommands = & (Get-Module m) { Get-Command | Where-Object { $_.Name -like "*aaa" } }
            $moduleCommands | Verify-Null
            $commands = Get-Command | Where-Object { $_.Name -like "*bbb" }
            $commands | Verify-Null
            $pesterCommands = & (Get-Module Pester) { Get-Command | Where-Object { $_.Name -like "*ccc" } }
            $pesterCommands | Verify-Null
        }
    }

    b "Mock not found throws" {
        t "Resolving to function that is not a mock in Should -Invoke throws helpful message" {
            # https://github.com/pester/Pester/issues/1878
            $sb = {
                BeforeAll {
                    Get-Module m | Remove-Module
                    New-Module m -ScriptBlock { } | Import-Module
                }

                Describe "d" {
                    It "i" {
                        Mock Start-Job -ModuleName m

                        # trying to assert on command that is not mocked in script scope
                        Should -Invoke Start-Job
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                    Run = @{ ScriptBlock = $sb; PassThru = $true }
                })

            $t = $r.Containers[0].Blocks[0].Tests[0]
            $t.Result | Verify-Equal "Failed"
            $t.ErrorRecord[0] | Verify-Equal 'Should -Invoke: Could not find Mock for command Start-Job in script scope. Was the mock defined? Did you use the same -ModuleName as on the Mock? When using InModuleScope are InModuleScope, Mock and Should -Invoke using the same -ModuleName?'
        }
    }

    b "Mock `$PesterBoundParameters" {
        t "Mock has `$PesterBoundParameters with bound parameters in body and filter" {
            # https://github.com/pester/Pester/issues/1542
            $sb = {
                BeforeAll {
                    Get-Module m | Remove-Module
                    New-Module m -ScriptBlock {
                        function i {
                            [CmdletBinding()]
                            param ($a, $b)
                        }
                    } | Import-Module
                }

                Describe "d" {
                    BeforeAll {
                    }

                    It "i" {

                        $container = @{}
                        Mock i -MockWith {
                            $container.MockBoundParameters = $PesterBoundParameters
                        } -ParameterFilter {
                            $container.FilterBoundParameters = $PesterBoundParameters
                            $true
                        }

                        i -a aaa
                        $container.MockBoundParameters.a | Should -Be "aaa"
                        $container.FilterBoundParameters.a | Should -Be "aaa"
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

    b "Mocks use current session state if module has the same name" {
        t "Mock uses the current session state if running in module instead of resolving the module by name" {
            # Not taking the current module when running inside of it will result in injecting mocks in a different session
            # state when InModuleScope is used and the module is re-impored
            # https://github.com/pester/Pester/issues/1939#issuecomment-840330972

            $sb = {
                # import module m and bind our tests to it
                Get-Module m | Remove-Module
                New-Module -Name m -ScriptBlock {
                    $id = [System.Guid]::NewGuid().Guid
                    function Get-Id { $id }

                    Export-ModuleMember -Function ""
                } | Import-Module


                InModuleScope m {
                    Describe 'm1' {
                        It 'we are in m, but also have m imported and they are not the same' {
                            # It is running after discovery, so the currently imported module m
                            # is the second one, not the first one that we are bound to
                            $mA = Get-Id
                            $mB = &(Get-Module m) { Get-Id }
                            $mA | Should -Not -Be $mB
                        }

                        It 'i1' {
                            # with the incorrect behavior mock will resolve module m by name
                            # and inject mocks into the second module, not into current session state
                            Mock Test-Path { "mock" }
                            # so test path would return False, instead of "mock"
                            Test-Path "aaa" | Should -Be "mock"
                        }
                    }
                }

                # import it one more time under the same name
                #
                # (when reproducing with scriptblock module you must not
                # use the same scriptblock, otherwise it won't work
                # the same way as with files, probably because files are
                # parsed again every time, but scriptblock is reused)
                Get-Module m | Remove-Module
                New-Module -Name m -ScriptBlock {
                    $id = [System.Guid]::NewGuid().Guid
                    function Get-Id { $id }

                    Export-ModuleMember -Function ""
                } | Import-Module

                InModuleScope m {
                    Describe 'm2' {
                        It 'i2' {
                            Mock Test-Path { "mock 2" }
                            Test-Path "aaa" | Should -Be "mock 2"
                        }
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                    Run = @{ ScriptBlock = $sb; PassThru = $true }
                })

            $t = $r.Containers[0]
            $t.Result | Verify-Equal "Passed"
        }
    }

    b "Should invoke parameter filter works when exexuted in a different module than the mock" {
        t "Should invoke can be invoked in module scope and it still uses the correct session state" {
            # https://github.com/pester/Pester/issues/1813

            $sb = {
                BeforeAll {
                    $script:moduleName = 'MyModule'

                    Remove-Module -Name 'MyModule' -Force -ErrorAction 'SilentlyContinue'

                    New-Module -Name 'MyModule' -ScriptBlock {
                        function Get-MyAlert {
                            write-warning "real function called!"
                        }

                        function New-MyAlert {
                            Get-MyAlert

                            $null = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Agent.Alert
                        }
                    } | Import-Module

                    $PSDefaultParameterValues = @{
                        'InModuleScope:ModuleName' = $script:moduleName
                    }
                }

                Describe 'InModuleScope' {
                    BeforeAll {
                        Mock -CommandName Get-MyAlert -ModuleName $script:moduleName
                        Mock -CommandName New-Object -ModuleName $script:moduleName -MockWith {
                            return 'anything'
                        } -ParameterFilter {
                            $TypeName -eq 'Microsoft.SqlServer.Management.Smo.Agent.Alert'
                        }
                    }

                    It 'Should call the mock' {
                        InModuleScope -ScriptBlock {
                            { New-MyAlert } | Should -Not -Throw
                        }

                        Should -Invoke -CommandName Get-MyAlert -ModuleName $script:moduleName -Exactly -Times 1 -Scope It

                        Should -Invoke -CommandName New-Object -ModuleName $script:moduleName -ParameterFilter {
                            $TypeName -eq 'Microsoft.SqlServer.Management.Smo.Agent.Alert'
                        } -Exactly -Times 1 -Scope It
                    }

                    It 'Should call the mock' {
                        InModuleScope -ScriptBlock {
                            { New-MyAlert } | Should -Not -Throw

                            Should -Invoke -CommandName Get-MyAlert -Exactly -Times 1 -Scope It

                            Should -Invoke -CommandName New-Object -ParameterFilter {
                                $TypeName -eq 'Microsoft.SqlServer.Management.Smo.Agent.Alert'
                            } -Exactly -Times 1 -Scope It
                        }
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                    Run = @{ ScriptBlock = $sb; PassThru = $true }
                })

            $t = $r.Containers[0]
            $t.Result | Verify-Equal "Passed"
        }
    }
}
