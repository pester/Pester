param ([switch] $PassThru, [switch] $NoBuild)

Get-Module P, PTestHelpers, Pester, Axiom | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

if (-not $NoBuild) { & "$PSScriptRoot\..\build.ps1" }
Import-Module $PSScriptRoot\..\bin\Pester.psd1

$global:PesterPreference = @{
    Debug  = @{
        ShowFullErrors         = $true
        WriteDebugMessages     = $false
        WriteDebugMessagesFrom = "Mock"
        ReturnRawResultObject  = $true
    }
    Output = @{
        Verbosity = "None"
    }
}
$PSDefaultParameterValues = @{}

i -PassThru:$PassThru {
    b "Running generated tests" {
        # # automation id is no-longer relevant I think
        # t "generating simple tests from foreach with external Id" {
        #     $sb = {
        #         Describe "d1" {
        #             foreach ($id in 1..10) {
        #                 It "it${id}" { $true } -AutomationId $id
        #             }
        #         }
        #     }

        #     $result.Containers[0].Blocks[0].ErrorRecord | Verify-Null
        #     $result.Containers[0].Blocks[0].Tests.Count | Verify-Equal 10
        #     $result.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
        # }

        # t "generating parametrized tests from foreach with external id" {
        #     $sb = {
        #         Describe "d1" {
        #             foreach ($id in 1..10) {
        #                 It "it$id-<value>" -TestCases @(
        #                     @{ Value = 1}
        #                     @{ Value = 2}
        #                     @{ Value = 3}
        #                 ) {
        #                     $true
        #                 } -AutomationId $id
        #             }
        #         }
        #     }

        #     $result.Containers[0].Blocks[0].ErrorRecord | Verify-Null
        #     $result.Containers[0].Blocks[0].Tests.Count | Verify-Equal 30
        #     $result.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
        # }

        t "generating simple tests from foreach without external Id" {
            $sb = {
                Describe "d1" {
                    foreach ($id in 1..10) {
                        It "it$id" { $true }
                    }
                }
            }
            $result = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $result.Containers[0].Blocks[0].ErrorRecord | Verify-Null
            $result.Containers[0].Blocks[0].Tests.Count | Verify-Equal 10
            $result.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
        }

        t "generating parametrized tests from foreach without external id" {
            $sb = {
                Describe "d1" {
                    foreach ($id in 1..10) {
                        It "it-$id-<value>" -TestCases @(
                            @{ Value = 1 }
                            @{ Value = 2 }
                            @{ Value = 3 }
                        ) {
                            $true
                        }
                    }
                }
            }
            $result = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $result.Containers[0].Blocks[0].ErrorRecord | Verify-Null
            $result.Containers[0].Blocks[0].Tests.Count | Verify-Equal 30
            $result.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
        }

        t "generating multiple parametrized tests from foreach without external id" {
            $sb = {
                Describe "d1" {
                    foreach ($id in 1..10) {
                        It "first-it-$id-<value>" -TestCases @(
                            @{ Value = 1 }
                            @{ Value = 2 }
                            @{ Value = 3 }
                        ) {
                            $true
                        }

                        It "second-it-$id-<value>" -TestCases @(
                            @{ Value = 1 }
                            @{ Value = 2 }
                            @{ Value = 3 }
                        ) {
                            $true
                        }
                    }
                }
            }
            $result = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $result.Containers[0].Blocks[0].ErrorRecord | Verify-Null
            $result.Containers[0].Blocks[0].Tests.Count | Verify-Equal 60
            $result.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
        }

        # automationId is not relevant right now
        #     t "generating multiple parametrized tests from foreach with external id" {
        #         $sb = {
        #             Describe "d1" {
        #                 foreach ($id in 1..10) {
        #                     It "first-it-$id-<value>" -TestCases @(
        #                         @{ Value = 1}
        #                         @{ Value = 2}
        #                         @{ Value = 3}
        #                     ) {
        #                         $true
        #                     } -AutomationId $Id

        #                     It "second-it-$id-<value>" -TestCases @(
        #                         @{ Value = 1}
        #                         @{ Value = 2}
        #                         @{ Value = 3}
        #                     ) {
        #                         $true
        #                     } -AutomationId $id
        #                 }
        #             }
        #         }

        #         $result.Containers[0].Blocks[0].ErrorRecord | Verify-Null
        #         $result.Containers[0].Blocks[0].Tests.Count | Verify-Equal 60
        #         $result.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
        #     }
    }

    b "BeforeAll paths" {
        t "`$PSScriptRoot in BeforeAll has the same value as in the script that calls it" {
            $container = [PSCustomObject]@{
                InScript    = $null
                InBeforeAll = $null
            }
            $sb = {
                $container.InScript = $PSScriptRoot
                BeforeAll {
                    $container.InBeforeAll = $PSScriptRoot
                }

                Describe "a" {
                    It "b" {
                        # otherwise the container would not run
                        $true
                    }
                }
            }
            $null = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $container.InBeforeAll | Verify-Equal $container.InScript
        }`
    }

    b "Invoke-Pester parameters" {
        try {
            $path = $pwd
            $c = 'Describe "d1" { It "i1" -Tag i1 { $true }; It "i2" -Tag i2 { $true }}'
            $tempDir = Join-Path ([IO.Path]::GetTempPath()) "dir"
            New-Item -ItemType Directory -Path $tempDir -Force
            $file1 = Join-Path $tempDir "file1.Tests.ps1"
            $file2 = Join-Path $tempDir "file2.Tests.ps1"

            $c | Set-Content $file1
            $c | Set-Content $file2
            cd $tempDir

            t "Running without any params runs all files from the local folder" {

                $result = Invoke-Pester -PassThru

                $result.Containers.Count | Verify-Equal 2
                $result.Containers[0].Item.FullName | Verify-Equal $file1
                $result.Containers[1].Item.FullName | Verify-Equal $file2
            }

            t "Running tests from Paths runs them" {
                $result = Invoke-Pester -Path $file1, $file2 -PassThru

                $result.Containers.Count | Verify-Equal 2
                $result.Containers[0].Item.FullName | Verify-Equal $file1
                $result.Containers[1].Item.FullName | Verify-Equal $file2
            }

            t "Exluding full path excludes it tests from Paths runs them" {
                $result = Invoke-Pester -Path $file1, $file2 -ExcludePath $file2 -PassThru

                $result.Containers.Count | Verify-Equal 1
                $result.Containers[0].Item | Verify-Equal $file1
            }

            t "Including tag runs just the test with that tag" {
                $result = Invoke-Pester -Path $file1 -Tag i1 -PassThru

                $result.Containers[0].Blocks[0].Tests[0].Executed | Verify-True
                $result.Containers[0].Blocks[0].Tests[1].Executed | Verify-False
            }

            t "Excluding tag skips the test with that tag" {
                $result = Invoke-Pester -Path $file1 -ExcludeTag i1 -PassThru

                $result.Containers[0].Blocks[0].Tests[0].Executed | Verify-False
                $result.Containers[0].Blocks[0].Tests[1].Executed | Verify-True
            }

            t "Scriptblock invokes inlined test" {
                $configuration = [PesterConfiguration]@{
                    Run = @{
                        Path        = $file1
                        ScriptBlock = { Describe "d1" { It "i1" { $true } } }
                        PassThru    = $true
                    }
                }

                $result = Invoke-Pester -Configuration $configuration
                $result.Containers[0].Blocks[0].Tests[0].Executed | Verify-True
            }

            t "Result object is not output by default" {
                $result = Invoke-Pester -Path $file1

                $result | Verify-Null
            }

            # t "CI generates code coverage and xml output" {
            #     $temp = [IO.Path]::GetTempPath()
            #     $path = "$temp/$([Guid]::NewGuid().Guid)"
            #     $pesterPath = (Get-Module Pester).Item

            #     try {
            #         New-Item -Path $path -ItemType Container | Out-Null

            #         $job = Start-Job {
            #             param ($PesterPath, $File, $Path)
            #             Import-Module $PesterPath
            #             Set-Location $Path
            #             Invoke-Pester $File -CI -Output None
            #         } -ArgumentList $pesterPath, $file1, $path

            #         $job | Wait-Job


            #         Test-Path "$path/testResults.xml" | Verify-True
            #         Test-Path "$path/coverage.xml" | Verify-True
            #     }
            #     finally {
            #         Remove-Item -Recurse -Force $path
            #     }
            # }
        }
        finally {
            cd $path
            Remove-Item $tempDir -Recurse -Force -Confirm:$false -ErrorAction Stop
        }
    }

    b "Terminating and non-terminating Should" {
        t "Non-terminating assertion fails the test after running to completion" {
            $sb = {
                Describe "d1" {
                    It "i1" {
                        $PSDefaultParameterValues = @{ 'Should:ErrorAction' = 'Continue' }
                        1 | Should -Be 2 # just write this error
                        "but still output this"
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $test = $r.Containers[0].Blocks[0].Tests[0]
            $test | Verify-NotNull
            $test.Result | Verify-Equal "Failed"
            $test.ErrorRecord[0].TargetObject.Terminating | Verify-False
            $test.ErrorRecord[0].Exception | Verify-NotNull
            $test.ErrorRecord[0].ScriptStackTrace | Verify-NotNull
            $test.ErrorRecord[0].DisplayErrorMessage | Verify-NotNull
            $test.ErrorRecord[0].DisplayStackTrace | Verify-NotNull
            $test.StandardOutput | Verify-Equal "but still output this"
        }

        t "Assertion does not fail immediately when ErrorActionPreference is set to Stop" {
            $sb = {
                Describe "d1" {
                    It "i1" {
                        $PSDefaultParameterValues = @{ 'Should:ErrorAction' = 'Continue' }
                        $ErrorActionPreference = 'Stop'
                        1 | Should -Be 2 # throw because of eap
                        "but still output this"
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $test = $r.Containers[0].Blocks[0].Tests[0]
            $test | Verify-NotNull
            $test.Result | Verify-Equal "Failed"
            $test.ErrorRecord[0].TargetObject.Terminating | Verify-False
            $test.ErrorRecord[0].Exception | Verify-NotNull
            $test.ErrorRecord[0].ScriptStackTrace | Verify-NotNull
            $test.ErrorRecord[0].DisplayErrorMessage | Verify-NotNull
            $test.ErrorRecord[0].DisplayStackTrace | Verify-NotNull
            $test.StandardOutput | Verify-Equal "but still output this"
        }

        t "Assertion fails immediately when -ErrorAction is set to Stop" {
            $sb = {
                Describe "d1" {
                    It "i1" {
                        1 | Should -Be 2 -ErrorAction Stop
                        "do not output this"
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                    Run    = @{ ScriptBlock = $sb; PassThru = $true }
                    Should = @{ ErrorAction = 'Continue' }
                })

            $test = $r.Containers[0].Blocks[0].Tests[0]
            $test | Verify-NotNull
            $test.Result | Verify-Equal "Failed"
            $test.ErrorRecord[0].TargetObject.Terminating | Verify-True
            $test.ErrorRecord[0].Exception | Verify-NotNull
            $test.ErrorRecord[0].ScriptStackTrace | Verify-NotNull
            $test.ErrorRecord[0].DisplayErrorMessage | Verify-NotNull
            $test.ErrorRecord[0].DisplayStackTrace | Verify-NotNull
            $test.StandardOutput | Verify-Null
        }

        t "Assertion fails immediately when ErrorAction is set to Stop via Default Parameters" {
            $sb = {
                Describe "d1" {
                    It "i1" {
                        $PSDefaultParameterValues = @{ 'Should:ErrorAction' = 'Stop' }
                        1 | Should -Be 2
                        "do not output this"
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $test = $r.Containers[0].Blocks[0].Tests[0]
            $test | Verify-NotNull
            $test.Result | Verify-Equal "Failed"
            $test.ErrorRecord[0].TargetObject.Terminating | Verify-True
            $test.ErrorRecord[0].Exception | Verify-NotNull
            $test.ErrorRecord[0].ScriptStackTrace | Verify-NotNull
            $test.ErrorRecord[0].DisplayErrorMessage | Verify-NotNull
            $test.ErrorRecord[0].DisplayStackTrace | Verify-NotNull
            $test.StandardOutput | Verify-Null
        }

        t "Assertion fails immediately when ErrorAction is set to Stop via global configuration" {
            $sb = {
                Describe "d1" {
                    It "i1" {
                        1 | Should -Be 2
                        "do not output this"
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })


            $test = $r.Containers[0].Blocks[0].Tests[0]
            $test | Verify-NotNull
            $test.Result | Verify-Equal "Failed"
            $test.ErrorRecord[0].TargetObject.Terminating | Verify-True
            $test.ErrorRecord[0].Exception | Verify-NotNull
            $test.ErrorRecord[0].ScriptStackTrace | Verify-NotNull
            $test.ErrorRecord[0].DisplayErrorMessage | Verify-NotNull
            $test.ErrorRecord[0].DisplayStackTrace | Verify-NotNull
            $test.StandardOutput | Verify-Null
        }

        t "Guard assertion" {
            $sb = {
                Describe "d1" {
                    It "User with guard" {
                        $user = $null # we failed to get user
                        $user | Should -Not -BeNullOrEmpty -ErrorAction Stop -Because "otherwise this test makes no sense"
                        $user.Name | Should -Be Jakub
                        $user.Age | Should -Be 31
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                    Run    = @{ ScriptBlock = $sb; PassThru = $true }
                    Should = @{ ErrorAction = 'Continue' }
                })

            $test = $r.Containers[0].Blocks[0].Tests[0]
            $test | Verify-NotNull
            $test.Result | Verify-Equal "Failed"
            $test.ErrorRecord[0].TargetObject.Terminating | Verify-True
            $test.ErrorRecord[0].Exception.Message | Verify-Equal "Expected a value, because otherwise this test makes no sense, but got `$null or empty."
            $test.ErrorRecord[0].ScriptStackTrace | Verify-NotNull
            $test.ErrorRecord[0].DisplayErrorMessage | Verify-NotNull
            $test.ErrorRecord[0].DisplayStackTrace | Verify-NotNull
            $test.StandardOutput | Verify-Null
        }

        t "Chaining assertions" {
            $sb = {
                Describe "d1" {
                    It "User with guard" {
                        $user = [PSCustomObject]@{ Name = "Tomas"; Age = 22 }
                        $user | Should -Not -BeNullOrEmpty -ErrorAction Stop -Because "otherwise this test makes no sense"
                        $user.Name | Should -Be Jakub
                        $user.Age | Should -Be 31
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{
                    Run    = @{ ScriptBlock = $sb; PassThru = $true }
                    Should = @{ ErrorAction = 'Continue' }
                })

            $test = $r.Containers[0].Blocks[0].Tests[0]
            $test | Verify-NotNull
            $test.Result | Verify-Equal "Failed"
            $test.ErrorRecord.Count | Verify-Equal 2
        }

        t "Should throws when called outside of Pester" {
            $PesterPreference = [PesterConfiguration]@{ Should = @{ ErrorAction = 'Continue' } }
            $err = { 1 | Should -Be 2 } | Verify-Throw
            $err.Exception.Message | Verify-Equal "Expected 2, but got 1."
        }
    }


    b "-Skip on Describe, Context and It" {
        t "It can be skipped" {
            $sb = {
                Describe "a" {
                    It "b" -Skip {
                        $true
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Skipped"
        }

        t "Describe can be skipped" {
            $sb = {
                Describe "a" -Skip {
                    It "b" {
                        $true
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Skipped"
        }

        t "Context can be skipped" {
            $sb = {
                Context "a" -Skip {
                    It "b" {
                        $true
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Skipped"
        }

        t "Skip will propagate through multiple levels" {
            $sb = {
                Describe "a" -Skip {
                    Describe "a" {
                        Describe "a" {
                            It "b" {
                                $true
                            }
                        }
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true } })

            $r.Containers[0].Blocks[0].Blocks[0].Blocks[0].Tests[0].Result | Verify-Equal "Skipped"
        }
    }

    b "Variables do not leak from top-level BeforeAll" {
        t "BeforeAll keeps a scoped to just the first scriptblock" {
            $sb = {
                BeforeAll {
                    $f = 10
                }

                Describe "d1" {
                    It "t1" {
                        $f | Should -Be 10
                    }
                }
            }

            $sb2 = {
                Describe "d2" {
                    It "t2" {
                        Get-Variable -Name f -ErrorAction Ignore -ValueOnly | Should -BeNullOrEmpty
                    }
                }
            }

            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb, $sb2; PassThru = $true } })

            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[1].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
        }
    }

    b "top-level AfterAll" {
        t "AfterAll can be used in top-level" {
            $sb = {
                AfterAll {
                    "teardown"
                }

                Describe "d1" {
                    It "t1" {

                    }
                }
            }
            write-Host "here"
            $c = New-PesterContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $c -PassThru -Output Detailed

            $r.Containers[0].StandardOutput | Verify-Equal "teardown"
        }
    }

    b "Parametric scripts" {
        t "Data can be passed to scripts" {
            $sb = {
                param ($Value)

                if ($Value -ne 1 -and $Value -ne 2) {
                    throw "Expected `$Value to be 1 or 2 but it is, '$Value'"
                }

                BeforeAll {
                    if ($Value -ne 1 -and $Value -ne 2) {
                        throw "Expected `$Value to be 1 or 2 but it is, '$Value'"
                    }
                }

                Describe "d1" {
                    It "t1" {
                        if ($Value -ne 1 -and $Value -ne 2) {
                            throw "Expected `$Value to be 1 or 2 but it is, '$Value'"
                        }
                    }
                }
            }

            $container = New-PesterContainer -ScriptBlock $sb -Data @(
                @{ Value = 1 }
                @{ Value = 2 }
            )
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[1].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
        }

        t "Single path with single set of data" {
            try {
                $sb = {
                    param (
                        [int] $Value
                    )

                    if ($Value -ne 1) {
                        throw "Expected `$Value to be 1 but it is, '$Value'"
                    }

                    BeforeAll {
                        if ($Value -ne 1) {
                            throw "Expected `$Value to be 1 but it is, '$Value'"
                        }
                    }

                    Describe "d1" {
                        It "t1" {
                            if ($Value -ne 1) {
                                throw "Expected `$Value to be 1 but it is, '$Value'"
                            }
                        }
                    }
                }

                $tmp = "$([IO.Path]::GetTempPath())/$([Guid]::NewGuid())"
                $null = New-Item $tmp -Force -ItemType Container
                $file = "$tmp/file1.Tests.ps1"
                $sb | Set-Content -Path $file

                $container = New-PesterContainer -Path $file -Data @{ Value = 1 }
                $r = Invoke-Pester -Container $container -PassThru
                $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            }
            finally {
                if ($null -ne $file -and (Test-Path $file)) {
                    Remove-Item $file -Force
                }
            }
        }

        t "Multiple instances of the same path each with it's own data" {
            try {
                $sb = {
                    param (
                        [int] $Value
                    )

                    if ($Value -ne 1 -and $Value -ne 2) {
                        throw "Expected `$Value to be 1 or 2 but it is, '$Value'"
                    }

                    BeforeAll {
                        if ($Value -ne 1 -and $Value -ne 2) {
                            throw "Expected `$Value to be 1 or 2 but it is, '$Value'"
                        }
                    }

                    Describe "d1" {
                        It "t1" {
                            if ($Value -ne 1 -and $Value -ne 2) {
                                throw "Expected `$Value to be 1 or 2 but it is, '$Value'"
                            }
                        }
                    }
                }

                $tmp = "$([IO.Path]::GetTempPath())/$([Guid]::NewGuid())"
                $null = New-Item $tmp -Force -ItemType Container
                $file = "$tmp/file1.Tests.ps1"
                $sb | Set-Content -Path $file

                $container = @(
                    (New-PesterContainer -Path $file -Data @{ Value = 1 })
                    (New-PesterContainer -Path $file -Data @{ Value = 2 })
                )
                $r = Invoke-Pester -Container $container -PassThru
                $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
                $r.Containers[1].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            }
            finally {
                if ($null -ne $file -and (Test-Path $file)) {
                    Remove-Item $file -Force
                }
            }
        }

        t "Single path with multiple sets of data (alternative to the above)" {
            try {
                $sb = {
                    param (
                        [int] $Value
                    )

                    if ($Value -ne 1 -and $Value -ne 2) {
                        throw "Expected `$Value to be 1 or 2 but it is, '$Value'"
                    }

                    BeforeAll {
                        if ($Value -ne 1 -and $Value -ne 2) {
                            throw "Expected `$Value to be 1 or 2 but it is, '$Value'"
                        }
                    }

                    Describe "d1" {
                        It "t1" {
                            if ($Value -ne 1 -and $Value -ne 2) {
                                throw "Expected `$Value to be 1 or 2 but it is, '$Value'"
                            }
                        }
                    }
                }

                $tmp = "$([IO.Path]::GetTempPath())/$([Guid]::NewGuid())"
                $null = New-Item $tmp -Force -ItemType Container
                $file = "$tmp/file1.Tests.ps1"
                $sb | Set-Content -Path $file

                $container = New-PesterContainer -Path $file -Data @(
                    @{ Value = 1 }
                    @{ Value = 2 }
                )
                $r = Invoke-Pester -Container $container -PassThru
                $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
                $r.Containers[1].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            }
            finally {
                if ($null -ne $file -and (Test-Path $file)) {
                    Remove-Item $file -Force
                }
            }
        }

        t "Multiple different paths each with it's own data" {
            try {
                $sb1 = {
                    param (
                        [int] $Value
                    )

                    if ($Value -ne 1 -and $Value -ne 2) {
                        throw "Expected `$Value to be 1 or 2 but it is, '$Value'"
                    }

                    BeforeAll {
                        if ($Value -ne 1 -and $Value -ne 2) {
                            throw "Expected `$Value to be 1 or 2 but it is, '$Value'"
                        }
                    }

                    Describe "d1" {
                        It "t1" {
                            if ($Value -ne 1 -and $Value -ne 2) {
                                throw "Expected `$Value to be 1 or 2 but it is, '$Value'"
                            }
                        }
                    }
                }

                $sb2 = {
                    param (
                        [string] $Color
                    )

                    if ($Color -ne "Blue" -and $Color -ne "Yellow") {
                        throw "Expected `$Color to be Blue or Yellow but it is, '$Color'"
                    }

                    BeforeAll {
                        if ($Color -ne "Blue" -and $Color -ne "Yellow") {
                            throw "Expected `$Color to be Blue or Yellow but it is, '$Color'"
                        }
                    }

                    Describe "d1" {
                        It "t1" {
                            if ($Color -ne "Blue" -and $Color -ne "Yellow") {
                                throw "Expected `$Color to be Blue or Yellow but it is, '$Color'"
                            }
                        }
                    }
                }

                $tmp = "$([IO.Path]::GetTempPath())/$([Guid]::NewGuid())"
                $null = New-Item $tmp -Force -ItemType Container
                $file1 = "$tmp/file1.Tests.ps1"
                $file2 = "$tmp/file2.Tests.ps1"
                $sb1 | Set-Content -Path $file1
                $sb2 | Set-Content -Path $file2

                $container = @(
                    (New-PesterContainer -Path $file1 -Data @(
                            @{ Value = 1 }
                            @{ Value = 2 }
                        ))

                    (New-PesterContainer -Path $file2 -Data @(
                            @{ Color = "Blue" }
                            @{ Color = "Yellow" }
                        ))
                )

                $r = Invoke-Pester -Container $container -PassThru # -Output Normal
                $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
                $r.Containers[1].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
                $r.Containers[2].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
                $r.Containers[3].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            }
            finally {
                if ($null -ne $file1 -and (Test-Path $file1)) {
                    Remove-Item $file1 -Force
                }

                if ($null -ne $file2 -and (Test-Path $file2)) {
                    Remove-Item $file2 -Force
                }
            }
        }

        t "Providing path with wildcard should expand the path to multiple containers" {
            try {
                $sb = {
                    param (
                        [int] $Value
                    )

                    if ($Value -ne 1 -and $Value -ne 2) {
                        throw "Expected `$Value to be 1 or 2 but it is, '$Value'"
                    }

                    Describe "d1" {
                        It "t1" {
                            if ($Value -ne 1 -and $Value -ne 2) {
                                throw "Expected `$Value to be 1 or 2 but it is, '$Value'"
                            }
                        }
                    }
                }

                $tmp = "$([IO.Path]::GetTempPath())/$([Guid]::NewGuid())"
                $null = New-Item $tmp -Force -ItemType Container
                $file1 = "$tmp/file1.Tests.ps1"
                $file2 = "$tmp/file2.Tests.ps1"
                $sb | Set-Content -Path $file1
                $sb | Set-Content -Path $file2

                # passing path to the whole directory with two test files
                $container = New-PesterContainer -Path $tmp -Data @(
                    @{ Value = 1 }
                    @{ Value = 2 }
                )

                $r = Invoke-Pester -Container $container -PassThru # -Output Normal
                $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
                $r.Containers[1].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
                $r.Containers[2].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
                $r.Containers[3].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            }
            finally {
                if ($null -ne $file1 -and (Test-Path $file1)) {
                    Remove-Item $file1 -Force
                }

                if ($null -ne $file2 -and (Test-Path $file2)) {
                    Remove-Item $file2 -Force
                }
            }
        }

        t "Providing path with wildcard that is in directory names should expand to all directories and all their test files" {
            try {
                $sb = {
                    param (
                        [int] $Value
                    )

                    if ($Value -ne 1 -and $Value -ne 2) {
                        throw "Expected `$Value to be 1 or 2 but it is, '$Value'"
                    }

                    Describe "d1" {
                        It "t1" {
                            if ($Value -ne 1 -and $Value -ne 2) {
                                throw "Expected `$Value to be 1 or 2 but it is, '$Value'"
                            }
                        }
                    }
                }

                $tmp = "$([IO.Path]::GetTempPath())/$([Guid]::NewGuid())"
                $tmp1 = $tmp + "PrefixDir1"
                $tmp2 = $tmp + "PrefixDir2"
                $null = New-Item ($tmp1) -Force -ItemType Container
                $null = New-Item ($tmp2) -Force -ItemType container
                $file1 = "$tmp1/file1.Tests.ps1"
                $file2 = "$tmp2/file2.Tests.ps1"
                $sb | Set-Content -Path $file1
                $sb | Set-Content -Path $file2

                # passing path to a wildcarded directory, that only uses part of the name as prefix
                $container = New-PesterContainer -Path ($tmp + "Prefix*" ) -Data @(
                    @{ Value = 1 }
                    @{ Value = 2 }
                )

                $r = Invoke-Pester -Container $container -PassThru # -Output Normal
                $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
                $r.Containers[1].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
                $r.Containers[2].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
                $r.Containers[3].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            }
            finally {
                if ($null -ne $file1 -and (Test-Path $file1)) {
                    Remove-Item $file1 -Force
                }

                if ($null -ne $file2 -and (Test-Path $file2)) {
                    Remove-Item $file2 -Force
                }
            }
        }

        t "Providing -Path that resolves to the same path as a parametrized script should skip that path" {
            try {
                $sb1 = {
                    param (
                        [int] $Value
                    )

                    if ($Value -ne 1) {
                        throw "Expected `$Value to be 1 but it is, '$Value'"
                    }

                    BeforeAll {
                        if ($Value -ne 1) {
                            throw "Expected `$Value to be 1 but it is, '$Value'"
                        }
                    }

                    Describe "d1" {
                        It "t1" {
                            if ($Value -ne 1) {
                                throw "Expected `$Value to be 1 but it is, '$Value'"
                            }
                        }
                    }
                }

                $sb2 = {
                    Describe "d2" {
                        It "t2" {
                            1 | Should -Be 1
                        }
                    }
                }

                $tmp = "$([IO.Path]::GetTempPath())/$([Guid]::NewGuid())"
                $null = New-Item $tmp -Force -ItemType Container
                $file1 = "$tmp/file1.Tests.ps1"
                $file2 = "$tmp/file2.Tests.ps1"
                $sb1 | Set-Content -Path $file1
                $sb2 | Set-Content -Path $file2

                $container = New-PesterContainer -Path $file1 -Data @{ Value = 1 }

                # the path to $file1 should be included only once, even though -Path $tmp will find that file as well
                # because we expect the parametrized script to require the parameters, but still want to allow
                # providing wildcard paths to run the rest of the test base
                $r = Invoke-Pester -Path $tmp -Container $container -PassThru -Output Normal
                $r.Containers.Count | Verify-Equal 2
                $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
                $r.Containers[1].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            }
            finally {
                if ($null -ne $file1 -and (Test-Path $file1)) {
                    Remove-Item $file1 -Force
                }

                if ($null -ne $file2 -and (Test-Path $file2)) {
                    Remove-Item $file2 -Force
                }
            }
        }

        t "Data provided to container are accessible in ForEach on each level" {
            $scenarios = @(
                @{
                    Scenario = @{
                        Name     = "A"
                        Contexts = @(
                            @{
                                Name     = "AA"
                                Examples = @(
                                    @{ User = @{ Name = "Jakub"; Age = 31 } }
                                    @{ User = @{ Name = "Tomas"; Age = 27 } }
                                )
                            }
                            @{
                                Name     = "AB"
                                Examples = @(
                                    @{ User = @{ Name = "Peter"; Age = 30 } }
                                    @{ User = @{ Name = "Jaap"; Age = 22 } }
                                )
                            }
                        )
                    }
                }
                @{
                    Scenario = @{
                        Name     = "B"
                        Contexts = @{
                            Name     = "BB"
                            Examples = @(
                                @{ User = @{ Name = "Jane"; Age = 25 } }
                            )
                        }
                    }
                }
            )

            $sb = {
                param ($Scenario)

                Describe "Scenario - <name>" -ForEach $Scenario {

                    Context "Context - <name>" -ForEach $Contexts {
                        It "Example - <user.name> with age <user.age> is less than 35" -ForEach $Examples {
                            $User.Age | Should -BeLessOrEqual 35
                        }
                    }
                }
            }

            $container = New-PesterContainer -ScriptBlock $sb -Data $scenarios

            $r = Invoke-Pester -Container $container -PassThru -Output Detailed
            $r.Containers[0].Blocks[0].ExpandedName | Verify-Equal "Scenario - A"
            $r.Containers[0].Blocks[0].Blocks[0].ExpandedName | Verify-Equal "Context - AA"
            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].ExpandedName | Verify-Equal "Example - Jakub with age 31 is less than 35"

            $r.Containers[0].Blocks[0].Blocks[1].ExpandedName | Verify-Equal "Context - AB"
            $r.Containers[0].Blocks[0].Blocks[1].Tests[0].ExpandedName | Verify-Equal "Example - Peter with age 30 is less than 35"
        }

        t "Data provided to container are accessible during Discovery and Run" {
            # issue: https://github.com/pester/Pester/issues/1770
            $sb = {
                param (
                    # the issue uses mandatory, I tried it with and without it and it works
                    # I am avoiding mandatory, because it will make the test ask for value when
                    # the parameter passing breaks
                    # [parameter(mandatory = $true)]
                    [string] $EnvironmentName
                )

                Describe "Application" {
                    It "Environment is <environmentName>" {
                        $EnvironmentName | Should -Be "Production"
                    }
                }
            }

            $container = New-PesterContainer -ScriptBlock $sb -Data @{ EnvironmentName = "Production" }

            $r = Invoke-Pester -Container $container -PassThru -Output Detailed
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
        }

        t "Parameter name is added to Data when alias is used" {
            # In normal PowerShell when calling a function/script with parameter-alias, only the real parameter name
            # should be defined as variable and PSBoundParameters. Since Pester uses user-provided Data raw **in Run-phase**,
            # we actually only provide alias in Run. We should at least add the parameter name as variable

            $sb = {
                param (
                    [Alias('MyAlias')]
                    $Value
                )

                if ($Value -ne 1) {
                    throw "Expected `$Value to be 1 but it is, '$Value'"
                }

                if (Get-Variable -Name 'MyAlias' -ErrorAction SilentlyContinue) {
                    # Normal PowerShell parameter-binding. Alias shouldn't be present
                    throw "Expected `$MyAlias not to be present as variable, but it was"
                }

                Describe "d1" {
                    It "t1" {
                        if ($Value -ne 1) {
                            # Added by parameter default-value function in Pester to behave like general PowerShell
                            # and be equal to Discovery
                            throw "Expected `$Value to be 1 but it is, '$Value'"
                        }

                        if ($MyAlias -ne 1) {
                            # Pester-specific behavior since we consume user-provided -Data directly
                            throw "Expected `$MyAlias to be 1 but it is, '$MyAlias'"
                        }
                    }
                }
            }

            $container = New-PesterContainer -ScriptBlock $sb -Data @{ MyAlias = 1 }
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
        }

        t 'Each container gets own copy of Data' {
            # https://github.com/pester/Pester/issues/2073
            # Default values for script parameters used to leak into other containers due to shared Data-reference.
            $sb1 = {
                param ($Value = 1)

                Describe 'd1' {
                    It 't1' {
                        if ($Value -ne 1) {
                            throw "Expected `$Value to be 1 but it is '$Value'"
                        }
                    }
                }
            }

            $sb2 = {
                param ($Value = 2)

                Describe 'd2' {
                    It 't2' {
                        if ($Value -ne 2) {
                            throw "Expected `$Value to be 2 but it is '$Value'"
                        }
                    }
                }
            }

            $container = New-PesterContainer -ScriptBlock $sb1, $sb2 -Data @{ }
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal 'Passed'
            $r.Containers[1].Blocks[0].Tests[0].Result | Verify-Equal 'Passed'
        }

        t 'Provided container data is not mutated during run' {
            # https://github.com/pester/Pester/issues/2357
            # Default values for script parameters used to leak into provided container-object, breaking reruns.
            $sb = {
                param ($Value = 1)

                Describe 'd1' {
                    It 't1' {
                        if ($Value -ne 1) {
                            throw "Expected `$Value to be 1 but it is '$Value'"
                        }
                    }
                }
            }

            $container = New-PesterContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal 'Passed'

            # Should still be empty (original state) after being used in Invoke-Pester
            $container.Data.Count | Verify-Equal 0
        }

        t 'Works with different dictionary types as Data' {
            $sb = {
                param ($Value)

                Describe 'd1' {
                    It 't1' {
                        if ($Value -ne 1) {
                            throw "Expected `$Value to be 1 but it is '$Value'"
                        }
                    }
                }
            }

            $ht = @{ Value = 1 }
            $ordered = [ordered]@{ Value = 1 }
            $generic =  New-Object 'System.Collections.Generic.Dictionary[string,int]'
            $generic.Add('Value', 1)

            $container = New-PesterContainer -ScriptBlock $sb -Data @($ht, $ordered, $generic)
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal 'Passed'
            $r.Containers[1].Blocks[0].Tests[0].Result | Verify-Equal 'Passed'
            $r.Containers[2].Blocks[0].Tests[0].Result | Verify-Equal 'Passed'
        }
    }

    b "Default values in parametric scripts" {
        t "Default values are automatically added to container Data when available and parameter is undefined" {
            try {
                # Making sure both Context and Describe blocks triggers the logic
                $sbDescribe = {
                    param (
                        [int] $Value = 123
                    )

                    if ($Value -ne 123) {
                        throw "Expected `$Value to be 123, but it is '$Value'"
                    }

                    BeforeAll {
                        if ($Value -ne 123) {
                            throw "Expected `$Value to be 123, but it is '$Value'"
                        }
                    }

                    Describe "d1" {
                        It "t1" {
                            if ($Value -ne 123) {
                                throw "Expected `$Value to be 123, but it is '$Value'"
                            }
                        }
                    }
                }

                $sbContext = {
                    param (
                        [int] $Value = 123
                    )

                    if ($Value -ne 123) {
                        throw "Expected `$Value to be 123, but it is '$Value'"
                    }

                    BeforeAll {
                        if ($Value -ne 123) {
                            throw "Expected `$Value to be 123, but it is '$Value'"
                        }
                    }

                    Context "c1" {
                        It "t1" {
                            if ($Value -ne 123) {
                                throw "Expected `$Value to be 123, but it is '$Value'"
                            }
                        }
                    }
                }

                $tmp = "$([IO.Path]::GetTempPath())/$([Guid]::NewGuid())"
                $null = New-Item $tmp -Force -ItemType Container
                $file = "$tmp/file1.Tests.ps1"
                $sbDescribe | Set-Content -Path $file

                # Testing both file and scriptblock containers
                $containers = @(
                    (New-PesterContainer -Path $file),
                    (New-PesterContainer -ScriptBlock $sbContext)
                )
                $r = Invoke-Pester -Container $containers -PassThru

                $r.Containers[0].Data.ContainsKey('Value') | Verify-True
                $r.Containers[1].Data.ContainsKey('Value') | Verify-True
                $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
                $r.Containers[1].Blocks[0].Tests[0].Result | Verify-Equal "Passed"

                # Also works without pre-creating a container
                $r2 = Invoke-Pester -Path $file -PassThru
                $r2.Containers[0].Data.ContainsKey('Value') | Verify-True
                $r2.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"

                # Interactive execution uses New-PesterContainer -Data covered by a test below
            }
            finally {
                if ($null -ne $file -and (Test-Path $file)) {
                    Remove-Item $file -Force
                }
            }
        }

        t "Default values are available in all root-level blocks" {
            try {
                $sb = {
                    param (
                        [int] $Value = 123
                    )

                    if ($Value -ne 123) {
                        throw "Expected `$Value to be 123, but it is '$Value'"
                    }

                    BeforeAll {
                        if ($Value -ne 123) {
                            throw "Expected `$Value to be 123, but it is '$Value'"
                        }
                    }

                    Describe "d1" {
                        It "t1" {
                            if ($Value -ne 123) {
                                throw "Expected `$Value to be 123, but it is '$Value'"
                            }
                        }
                    }

                    Context "c1" {
                        It "t1" {
                            if ($Value -ne 123) {
                                throw "Expected `$Value to be 123, but it is '$Value'"
                            }
                        }
                    }
                }

                $tmp = "$([IO.Path]::GetTempPath())/$([Guid]::NewGuid())"
                $null = New-Item $tmp -Force -ItemType Container
                $file = "$tmp/file1.Tests.ps1"
                $sb | Set-Content -Path $file

                $r = Invoke-Pester -Path $file -PassThru

                $r.Containers[0].Data.Count | Verify-Equal 1
                $r.Containers[0].Data.ContainsKey('Value') | Verify-True
                $r.Containers[0].Data['Value'] | Verify-Equal 123

                $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
                $r.Containers[0].Blocks[1].Tests[0].Result | Verify-Equal "Passed"
            }
            finally {
                if ($null -ne $file -and (Test-Path $file)) {
                    Remove-Item $file -Force
                }
            }
        }

        t "Uses evaluated default and includes null-defaults including non-defined" {
            try {
                $sb = {
                    param (
                        [int] $Value = 123,
                        $OtherParam,
                        $MyNullParam = $null,
                        $ExpressionParam = $(5 % 2)
                    )

                    if ($Value -ne 123) {
                        throw "Expected `$Value to be 123, but it is '$Value'"
                    }

                    if ($ExpressionParam -ne 1) {
                        throw "Expected `$ExpressionParam to be 1, but it is '$ExpressionParam'"
                    }

                    BeforeAll {
                        if ($Value -ne 123) {
                            throw "Expected `$Value to be 123, but it is '$Value'"
                        }
                    }

                    Describe "d1" {
                        It "t1" {
                            if ($Value -ne 123) {
                                throw "Expected `$Value to be 123, but it is '$Value'"
                            }

                            $v = Get-Variable -Name 'OtherParam'
                            $v | Should -Not -BeNullOrEmpty
                            $v.Value | Should -BeNullOrEmpty
                        }
                    }

                    Context "c1" {
                        It "t1" {
                            if ($ExpressionParam -ne 1) {
                                throw "Expected `$ExpressionParam to be 1, but it is '$ExpressionParam'"
                            }

                            $v2 = Get-Variable -Name 'MyNullParam'
                            $v2 | Should -Not -BeNullOrEmpty
                            $v2.Value | Should -BeNullOrEmpty
                        }
                    }
                }

                $tmp = "$([IO.Path]::GetTempPath())/$([Guid]::NewGuid())"
                $null = New-Item $tmp -Force -ItemType Container
                $file = "$tmp/file1.Tests.ps1"
                $sb | Set-Content -Path $file

                $r = Invoke-Pester -Path $file -PassThru

                $r.Containers[0].Data.Count | Verify-Equal 4
                $r.Containers[0].Data.ContainsKey('Value') | Verify-True
                $r.Containers[0].Data['Value'] | Verify-Equal 123
                # Should include parameters without user-defined default value
                $r.Containers[0].Data.ContainsKey('OtherParam') | Verify-True
                $r.Containers[0].Data['OtherParam'] | Verify-Null
                # Should include parameters with default value of $null
                $r.Containers[0].Data.ContainsKey('MyNullParam') | Verify-True
                $r.Containers[0].Data['MyNullParam'] | Verify-Null
                # Includes the evaluated default value, not the expression
                $r.Containers[0].Data.ContainsKey('ExpressionParam') | Verify-True
                $r.Containers[0].Data['ExpressionParam'] | Verify-Equal 1

                $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
                $r.Containers[0].Blocks[1].Tests[0].Result | Verify-Equal "Passed"
            }
            finally {
                if ($null -ne $file -and (Test-Path $file)) {
                    Remove-Item $file -Force
                }
            }
        }

        t "Only adds parameter-names as variables" {
            $sb = {
                param (
                    [Alias('MyAlias')]
                    $Value = 123
                )

                if ($Value -ne 123) {
                    throw "Expected `$Value to be 123, but it is '$Value'"
                }

                if (Get-Variable -Name 'MyAlias' -ErrorAction SilentlyContinue) {
                    throw "Expected `$MyAlias not to be present as variable, but it was"
                }

                Describe "d1" {
                    It "t1" {
                        if ($Value -ne 123) {
                            throw "Expected `$Value to be 123, but it is '$Value'"
                        }

                        if (Get-Variable -Name 'MyAlias' -ErrorAction SilentlyContinue) {
                            throw "Expected `$MyAlias not to be present as variable, but it was"
                        }
                    }
                }
            }

            $container = New-PesterContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru

            $r.Containers[0].Data.Count | Verify-Equal 1
            $r.Containers[0].Data.ContainsKey('Value') | Verify-True
            $r.Containers[0].Data['Value'] | Verify-Equal 123
            # Should not include alias as variable
            $r.Containers[0].Data.ContainsKey('MyAlias') | Verify-False

            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
        }

        t "Private scoped parameters are only available in root-level setup " {
            try {
                $sb = {
                    param (
                        [int] $private:Value = 123
                    )

                    if ($Value -ne 123) {
                        throw "Expected `$Value to be 123, but it is '$Value'"
                    }

                    BeforeAll {
                        if ($Value -ne 123) {
                            throw "Expected `$Value to be 123, but it is '$Value'"
                        }
                    }

                    Describe "d1" {
                        BeforeAll {
                            { Get-Variable -Name 'Value' -ErrorAction Stop } | Should -Throw -ExceptionType ([System.Management.Automation.ItemNotFoundException])
                        }

                        It "t1" {
                            { Get-Variable -Name 'Value' -ErrorAction Stop } | Should -Throw -ExceptionType ([System.Management.Automation.ItemNotFoundException])
                        }
                    }
                }

                $tmp = "$([IO.Path]::GetTempPath())/$([Guid]::NewGuid())"
                $null = New-Item $tmp -Force -ItemType Container
                $file = "$tmp/file1.Tests.ps1"
                $sb | Set-Content -Path $file

                $containers = @(
                    (New-PesterContainer -Path $file),
                    (New-PesterContainer -ScriptBlock $sb)
                )
                $r = Invoke-Pester -Container $containers -PassThru

                $r.Containers[0].Data.ContainsKey('private:Value') | Verify-True
                $r.Containers[0].Data['private:Value'] | Verify-Equal 123
                $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"

                $r.Containers[1].Data.ContainsKey('private:Value') | Verify-True
                $r.Containers[1].Data['private:Value'] | Verify-Equal 123
                $r.Containers[1].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            }
            finally {
                if ($null -ne $file -and (Test-Path $file)) {
                    Remove-Item $file -Force
                }
            }
        }

        t "Parameter default values won't override user-provided parameter values" {
            try {
                $sb = {
                    param (
                        [int] $Value = 123,
                        [string] $MyString = 'Oh no!'
                    )

                    if ($Value -ne 123) {
                        throw "Expected `$Value to be 123, but it is, '$Value'"
                    }

                    if ($MyString -ne 'Yay!') {
                        throw "Expected `$MyString to be 'Yay!', but it is, '$MyString'"
                    }

                    BeforeAll {
                        if ($Value -ne 123) {
                            throw "Expected `$Value to be 123 but it is, '$Value'"
                        }
                        if ($MyString -ne 'Yay!') {
                            throw "Expected `$MyString to be 'Yay!', but it is, '$MyString'"
                        }
                    }

                    Describe "d1" {
                        It "t1" {
                            if ($Value -ne 123) {
                                throw "Expected `$Value to be 123 but it is, '$Value'"
                            }
                            if ($MyString -ne 'Yay!') {
                                throw "Expected `$MyString to be 'Yay!', but it is, '$MyString'"
                            }
                        }
                    }
                }

                $tmp = "$([IO.Path]::GetTempPath())/$([Guid]::NewGuid())"
                $null = New-Item $tmp -Force -ItemType Container
                $file = "$tmp/file1.Tests.ps1"
                $sb | Set-Content -Path $file

                $containers = @(
                    (New-PesterContainer -Path $file -Data @{ MyString = "Yay!" }),
                    (New-PesterContainer -ScriptBlock $sb -Data @{ MyString = "Yay!" })
                )
                $r = Invoke-Pester -Container $containers -PassThru

                $r.Containers[0].Data.ContainsKey('Value') | Verify-True
                $r.Containers[0].Data['Value'] | Verify-Equal 123
                $r.Containers[0].Data.ContainsKey('MyString') | Verify-True
                $r.Containers[0].Data['MyString'] | Verify-Equal "Yay!"

                $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
                $r.Containers[1].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            }
            finally {
                if ($null -ne $file -and (Test-Path $file)) {
                    Remove-Item $file -Force
                }
            }
        }

        t "Parameter default values aren't overriden by changes in BeforeDiscovery" {
            # https://github.com/pester/Pester/issues/2359
            $sb = {
                param (
                    [int] $Value = 123
                )

                if ($Value -ne 123) {
                    throw "Expected `$Value to be 123, but it is, '$Value'"
                }

                # KNOWN ISSUE: Changes to $Value here, outside BeforeDiscovery, would be used as parameter default value in Data.
                # Can't fix as we don't have a hook beetween script execution and first call to a Pester-function

                BeforeDiscovery {
                    $Value = 456 # Should not override default value in Data
                }

                BeforeAll {
                    if ($Value -ne 123) {
                        throw "Expected `$Value to be 123 but it is, '$Value'"
                    }
                }

                Describe 'd1' {
                    It 't1' {
                        if ($Value -ne 123) {
                            throw "Expected `$Value to be 123 but it is, '$Value'"
                        }
                    }
                }
            }

            $container = New-PesterContainer -ScriptBlock $sb -Data @{ }
            $r = Invoke-Pester -Container $container -PassThru

            $r.Containers[0].Data.ContainsKey('Value') | Verify-True
            $r.Containers[0].Data['Value'] | Verify-Equal 123

            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal 'Passed'
        }
    }

    b "New-PesterContainer" {
        t "It works when file is provided via New-PesterContainer" {
            try {
                $sb = {
                    Describe "d1" {
                        It "t1" {
                            1 | Should -Be 1
                        }
                    }
                }

                $tmp = "$([IO.Path]::GetTempPath())/$([Guid]::NewGuid())"
                $null = New-Item $tmp -Force -ItemType Container
                $file = "$tmp/file1.Tests.ps1"
                $sb | Set-Content -Path $file

                $container = New-PesterContainer -Path $file

                $r = Invoke-Pester -Container $container -PassThru -Output Normal
                $r.Containers.Count | Verify-Equal 1
                $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            }
            finally {
                if ($null -ne $file -and (Test-Path $file)) {
                    Remove-Item $file -Force
                }
            }
        }

        t "It works when file is provided via Configuration" {
            try {
                $sb = {
                    Describe "d1" {
                        It "t1" {
                            1 | Should -Be 1
                        }
                    }
                }

                $tmp = "$([IO.Path]::GetTempPath())/$([Guid]::NewGuid())"
                $null = New-Item $tmp -Force -ItemType Container
                $file = "$tmp/file1.Tests.ps1"
                $sb | Set-Content -Path $file

                $container = New-PesterContainer -Path $file

                $configuration = [PesterConfiguration]::Default
                $configuration.Run.Container = $container
                $configuration.Run.PassThru = $true
                $configuration.Output.Verbosity = "Normal"

                $r = Invoke-Pester -Configuration $configuration
                $r.Containers.Count | Verify-Equal 1
                $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            }
            finally {
                if ($null -ne $file -and (Test-Path $file)) {
                    Remove-Item $file -Force
                }
            }
        }

        t "Does not accept unbound scriptblocks" {
            # Would execute in Pester's internal module state
            $ex = { New-PesterContainer -ScriptBlock ([ScriptBlock]::Create('$true')) } | Verify-Throw
            $ex.Exception.Message | Verify-Like 'Unbound scriptblock*'
        }
    }

    b "BeforeDiscovery" {
        t "Variables from BeforeDiscovery are defined in scope" {
            $sb = {
                BeforeDiscovery {
                    $tests = 1, 2
                }

                foreach ($t in $tests) {
                    Describe "d$t" {
                        It "t$t" -TestCases @{ t = $t } {
                            $t | Should -BeLessOrEqual 2
                        }
                    }
                }
            }

            $container = New-PesterContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[1].Tests[0].Result | Verify-Equal "Passed"
        }

        t "Does not accept unbound scriptblocks" {
            # Would execute in Pester's internal module state
            $sb = { BeforeDiscovery ([ScriptBlock]::Create('$true')) }
            $container = New-PesterContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Result | Verify-Equal 'Failed'
            $r.Containers[0].ErrorRecord.Exception.Message | Verify-Like 'Unbound scriptblock*'
        }
    }

    b "Parametric tests" {
        t "Providing data will generate as many Its as there are data sets" {
            $sb = {
                Describe "d" {
                    It "i" {
                    } -ForEach @(@{ Value = 1 }, @{ Value = 2 })
                }
            }

            $container = New-PesterContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests.Count | Verify-Equal 2
        }

        t "-TestCases is alias to -ForEach" {
            $sb = {
                Describe "d" {
                    It "i" {
                    } -TestCases @(@{ Value = 1 }, @{ Value = 2 })
                }
            }

            $container = New-PesterContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests.Count | Verify-Equal 2
        }

        t "Providing empty or `$null -ForEach will generate nothing when Run.FailOnNullOrEmptyForEach is False" {
            $sb = {
                Describe 'd' {
                    It 'i' { } -ForEach @()
                }

                Describe 'd' {
                    It 'i' { } -ForEach $null
                }
            }

            $c = New-PesterConfiguration
            $c.Run.Container = New-PesterContainer -ScriptBlock $sb
            $c.Run.FailOnNullOrEmptyForEach = $false
            $c.Run.PassThru = $true
            $r = Invoke-Pester -Configuration $c

            $r.Containers[0].Blocks[0].Tests.Count | Verify-Equal 0
            $r.Containers[0].Blocks[1].Tests.Count | Verify-Equal 0
        }

        t "Providing empty or `$null -ForEach will throw when Run.FailOnNullOrEmptyForEach is True" {
            $sbEmpty = {
                Describe 'd' {
                    It 'i' { } -ForEach @()
                }
            }

            $sbNull = {
                Describe 'd' {
                    It 'i' { } -ForEach $null
                }
            }

            $c = New-PesterConfiguration
            $c.Run.Container = New-PesterContainer -ScriptBlock $sbEmpty, $sbNull
            $c.Run.FailOnNullOrEmptyForEach = $true
            $c.Run.PassThru = $true
            $r = Invoke-Pester -Configuration $c

            $r.Result = 'Failed'
            $r.Containers[0].Result = 'Failed'
            $r.Containers[0].ErrorRecord.Exception | Verify-Type ([System.ArgumentException])
            $r.Containers[1].Result = 'Failed'
            $r.Containers[1].ErrorRecord.Exception | Verify-Type ([System.ArgumentException])
        }

        t "Providing empty or `$null -ForEach will generate nothing when using -AllowNullOrEmptyForEach" {
            $sb = {
                Describe 'd' {
                    It 'i' { } -ForEach @() -AllowNullOrEmptyForEach
                }

                Describe 'd' {
                    It 'i' { } -ForEach $null -AllowNullOrEmptyForEach
                }
            }

            $c = New-PesterConfiguration
            $c.Run.Container = New-PesterContainer -ScriptBlock $sb
            $c.Run.FailOnNullOrEmptyForEach = $true # Default but AllowNullOrEmptyForEach doesn't make sense without it
            $c.Run.PassThru = $true
            $r = Invoke-Pester -Configuration $c

            $r.Containers[0].Blocks[0].Tests.Count | Verify-Equal 0
            $r.Containers[0].Blocks[1].Tests.Count | Verify-Equal 0
        }
    }

    b 'Parametric blocks' {
        t 'Providing data will generate as many blocks as there are data sets' {
            $sb = {
                Describe 'd' {
                    Context 'c' {
                        It 'i' {
                        }
                    } -ForEach @(@{ Value = 1 }, @{ Value = 2 })
                } -ForEach @(@{ Value = 1 }, @{ Value = 2 })
            }

            $container = New-PesterContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru

            $r.Containers[0].Blocks.Count | Verify-Equal 2
            $r.Containers[0].Blocks[0].Blocks.Count | Verify-Equal 2
            $r.Containers[0].Blocks[1].Blocks.Count | Verify-Equal 2
        }

        t "Providing empty or `$null to -ForEach will generate nothing when Run.FailOnNullOrEmptyForEach is False" {
            $sbDescribe = {
                Describe 'dEmpty' {
                    It 'i' { }
                } -ForEach @()

                Describe 'dNull' {
                    It 'i' { }
                } -ForEach $null
            }

            $sbContext = {
                Describe 'dContext' {
                    Context 'cEmpty' {
                        It 'i' { }
                    } -ForEach @()

                    Context 'cNull' {
                        It 'i' { }
                    } -ForEach $null
                }
            }

            $c = New-PesterConfiguration
            $c.Run.Container = New-PesterContainer -ScriptBlock $sbDescribe, $sbContext
            $c.Run.FailOnNullOrEmptyForEach = $false
            $c.Run.PassThru = $true
            $r = Invoke-Pester -Configuration $c

            $r.Containers[0].Blocks.Count | Verify-Equal 0 # No Describe-blocks will be generated

            $r.Containers[1].Blocks.Count | Verify-Equal 1
            $r.Containers[1].Blocks[0].Name | Verify-Equal 'dContext'
            $r.Containers[1].Blocks[0].Blocks.Count | Verify-Equal 0 # No Context-blocks will be generated
        }

        t "Providing empty or `$null to -ForEach will throw when Run.FailOnNullOrEmptyForEach is True" {
            $sbDescribeEmpty = {
                Describe 'dEmpty' {
                    It 'i' { }
                } -ForEach @()
            }
            $sbDescribeNull = {
                Describe 'dNull' {
                    It 'i' { }
                } -ForEach $null
            }

            $sbContextEmpty = {
                Describe 'dContext' {
                    Context 'cEmpty' {
                        It 'i' { }
                    } -ForEach @()
                }
            }
            $sbContextNull = {
                Describe 'dContext' {
                    Context 'cNull' {
                        It 'i' { }
                    } -ForEach $null
                }
            }

            $c = New-PesterConfiguration
            $c.Run.Container = New-PesterContainer -ScriptBlock $sbDescribeEmpty, $sbDescribeNull, $sbContextEmpty, $sbContextNull
            $c.Run.FailOnNullOrEmptyForEach = $true
            $c.Run.PassThru = $true
            $r = Invoke-Pester -Configuration $c

            $r.Result = 'Failed'
            $r.Containers[0].Result = 'Failed'
            $r.Containers[0].ErrorRecord.Exception | Verify-Type ([System.ArgumentException])
            $r.Containers[1].Result = 'Failed'
            $r.Containers[1].ErrorRecord.Exception | Verify-Type ([System.ArgumentException])
            $r.Containers[2].Result = 'Failed'
            $r.Containers[2].ErrorRecord.Exception | Verify-Type ([System.ArgumentException])
            $r.Containers[3].Result = 'Failed'
            $r.Containers[3].ErrorRecord.Exception | Verify-Type ([System.ArgumentException])
        }

        t "Providing empty or `$null to -ForEach will generate nothing when using -AllowNullOrEmptyForEach" {
            $sbDescribe = {
                Describe 'dEmpty' {
                    It 'i' { }
                } -ForEach @() -AllowNullOrEmptyForEach

                Describe 'dNull' {
                    It 'i' { }
                } -ForEach $null -AllowNullOrEmptyForEach
            }

            $sbContext = {
                Describe 'dContext' {
                    Context 'cEmpty' {
                        It 'i' { }
                    } -ForEach @() -AllowNullOrEmptyForEach

                    Context 'cNull' {
                        It 'i' { }
                    } -ForEach $null -AllowNullOrEmptyForEach
                }
            }

            $c = New-PesterConfiguration
            $c.Run.Container = New-PesterContainer -ScriptBlock $sbDescribe, $sbContext
            $c.Run.FailOnNullOrEmptyForEach = $true # Default but AllowNullOrEmptyForEach doesn't make sense without it
            $c.Run.PassThru = $true
            $r = Invoke-Pester -Configuration $c

            $r.Containers[0].Blocks.Count | Verify-Equal 0 # No Describe-blocks will be generated

            $r.Containers[1].Blocks.Count | Verify-Equal 1
            $r.Containers[1].Blocks[0].Name | Verify-Equal 'dContext'
            $r.Containers[1].Blocks[0].Blocks.Count | Verify-Equal 0 # No Context-blocks will be generated
        }

        t "Data will be available in the respective block during Run" {
            $sb = {
                Describe "d" {
                    BeforeAll {
                        if ($Value -notin 1, 2) { throw "`$Value should be 1 or 2 but is '$Value'." }
                    }

                    BeforeEach {
                        if ($Value -notin 1, 2) { throw "`$Value should be 1 or 2 but is '$Value'." }
                    }

                    It "i" {
                        if ($Value -notin 1, 2) { throw "`$Value should be 1 or 2 but is '$Value'." }
                    }

                    AfterEach {
                        if ($Value -notin 1, 2) { throw "`$Value should be 1 or 2 but is '$Value'." }
                    }

                    AfterAll {
                        if ($Value -notin 1, 2) { throw "`$Value should be 1 or 2 but is '$Value'." }
                    }
                } -ForEach @(@{ Value = 1 }, @{ Value = 2 })
            }

            $container = New-PesterContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[1].Tests[0].Result | Verify-Equal "Passed"
        }

        t "`$_ holds the whole hashtable when hastable is used, and it is not overwritten in It" {
            $sb = {
                Describe "d" {
                    BeforeAll {
                        if ($_.Value -notin 1, 2) { throw "`$Value should be 1 or 2 but is '$($_.Value)'." }
                    }

                    It "i" {
                        if ($_.Value -notin 1, 2) { throw "`$Value should be 1 or 2 but is '$($_.Value)'." }
                    }
                } -ForEach @(@{ Value = 1 }, @{ Value = 2 })
            }

            $container = New-PesterContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[1].Tests[0].Result | Verify-Equal "Passed"
        }

        t "`$_ holds the whole hashtable when hastable is used, and it is overwritten in It if it specifies its own data" {
            $sb = {
                Describe "d" {
                    BeforeAll {
                        if ($_.Value -notin 1, 2) { throw "`$Value should be 1 or 2 but is '$($_.Value)'." }
                    }

                    It "i" {
                        if ($_.Value -ne 10) { throw "`$Value should be 10 '$($_.Value)'." }
                    } -ForEach @{ Value = 10 }
                } -ForEach @(@{ Value = 1 }, @{ Value = 2 })
            }

            $container = New-PesterContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[1].Tests[0].Result | Verify-Equal "Passed"
        }

        t "`$_ holds the current item array of any object is used, and it is overwritten in It if it specifies its own data" {
            $sb = {
                Describe "d" {
                    BeforeAll {
                        if ($_ -notin 1, 2) { throw "`$Value should be 1 or 2 but is '$_'." }
                    }

                    # maybe a bit unexpected to get the values of TestCases here, but BeforeEach
                    # runs in the same scope as It, so the variables are available there as well
                    BeforeEach {
                        if ($_ -notin 3, 4) { throw "`$Value should be 3 or 4 but is '$_'." }
                    }

                    It "i" {
                        if ($_ -notin 3, 4) { throw "`$Value should be 3 or 4 but is '$_'." }
                    } -ForEach 3, 4
                } -ForEach 1, 2
            }

            $container = New-PesterContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[1].Tests[0].Result | Verify-Equal "Passed"
        }

        t "<_> expands to `$_ in Describe and It" {
            $sb = {
                Describe "d <_>" {
                    It "i <_>" { } -ForEach 2
                } -ForEach 1
            }

            $container = New-PesterContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[0].ExpandedName | Verify-Equal "i 2"
            $r.Containers[0].Blocks[0].ExpandedName | Verify-Equal "d 1"
        }

        t "<_> expands to `$_ in It even if It does not define any data" {
            $sb = {
                Describe "d <_>" {
                    It "i <_>" {
                        $_ | Should -Be 1
                    }
                } -ForEach 1
            }

            $container = New-PesterContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[0].ExpandedName | Verify-Equal "i 1"
            $r.Containers[0].Blocks[0].ExpandedName | Verify-Equal "d 1"
        }

        t "ExpandedPath is expanded for parent blocks when block setup fails" {
            $sb = {
                Describe 'd <_>' {
                    Describe 'd2 <_>' {
                        BeforeAll { throw 'oh no' }
                        It 'i <_>' { $_ | Should -Be 1 }
                    }
                } -ForEach 1
            }

            $container = New-PesterContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Blocks[0].Result | Verify-Equal 'Failed'
            $r.Containers[0].Blocks[0].Blocks[0].ExpandedName | Verify-Equal 'd2 <_>'
            # ExpandedPath is updated as far as possible (parent block) before failure in block
            $r.Containers[0].Blocks[0].Blocks[0].ExpandedPath | Verify-Equal 'd 1.d2 <_>'
        }

        t "ExpandedPath is expanded for parent blocks when test is skipped or fails in BeforeEach" {
            $sb = {
                Describe 'd <_>' {
                    It 'i <_>' -Skip { $_ | Should -Be 2 }
                } -ForEach 1
                Describe 'd <_>' {
                    BeforeEach { throw 'oh no' }
                    It 'i <_>' { $_ | Should -Be 2 }
                } -ForEach 2
            }

            $container = New-PesterContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            # when test skipped
            $r.Containers[0].Blocks[0].ExpandedName | Verify-Equal 'd 1'
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal 'Skipped'
            $r.Containers[0].Blocks[0].Tests[0].ExpandedName | Verify-Equal 'i <_>'
            $r.Containers[0].Blocks[0].Tests[0].ExpandedPath | Verify-Equal 'd 1.i <_>'
            # when test setup failed
            $r.Containers[0].Blocks[1].ExpandedName | Verify-Equal 'd 2'
            $r.Containers[0].Blocks[1].Tests[0].ExpandedName | Verify-Equal 'i <_>'
            $r.Containers[0].Blocks[1].Tests[0].ExpandedPath | Verify-Equal 'd 2.i <_>'
        }

        t "<user.name> expands to `$user.name" {
            $sb = {
                Describe "d <user.name>" {
                    It "i <user.name>" { }
                } -ForEach @(@{User = @{ Name = "Jakub" } })
            }

            $container = New-PesterContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[0].ExpandedName | Verify-Equal "i Jakub"
            $r.Containers[0].Blocks[0].ExpandedName | Verify-Equal "d Jakub"
        }

        t "`$variable remains as literal text after expanding" {
            $sb = {
                Describe "d `$abc" {
                    It "i `$abc" { }
                } -ForEach @(@{User = @{ Name = "Jakub" } })
            }

            $container = New-PesterContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[0].ExpandedName | Verify-Equal "i `$abc"
            $r.Containers[0].Blocks[0].ExpandedName | Verify-Equal "d `$abc"
        }

        t 'template can be escaped by grave accent' {
            $sb = {
                Describe "d ``<fff``>" {
                    It 'i `<fff`>' { }
                } -ForEach @(@{User = @{ Name = "Jakub" } })
            }

            $container = New-PesterContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[0].ExpandedName | Verify-Equal "i `<fff`>"
            $r.Containers[0].Blocks[0].ExpandedName | Verify-Equal "d `<fff`>"
        }

        t 'template evaluates simple code' {
            $sb = {
                Describe "d" {
                    It 'i <user.name> is <user.Name.GetType()>' { }
                } -ForEach @(@{User = @{ Name = "Jakub" } })
            }

            $container = New-PesterContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru -Output Detailed
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[0].ExpandedName | Verify-Equal "i Jakub is string"
        }
    }

    b "Running Pester in Pester" {
        t "Invoke-Pester can run in Invoke-Pester" {
            $container = New-PesterContainer -ScriptBlock {
                Describe "Run Pester in Pester" {
                    It "Runs the test" {
                        $c = New-PesterContainer -ScriptBlock {
                            Describe "d" {
                                It "i" {
                                    1 | Should -Be 1
                                }
                            }
                        }

                        $r = Invoke-Pester -Container $c -PassThru
                        $r.TotalCount | Should -Be 1
                    }
                }
            }

            $result = Invoke-Pester -Container $container -PassThru
            $result.TotalCount | Verify-Equal 1
        }
    }

    b "Converting Pester 5 to Pester4 result" {
        t "It uses version 4.99.0" {
            # https://github.com/pester/Pester/issues/1786
            # .0 because I want some spare numbers if needed in the future
            $container = New-PesterContainer -ScriptBlock {
                Describe "d" {
                    It "t" {
                        1 | Should -Be 1
                    }
                }
            }

            $result = Invoke-Pester -Container $container -PassThru | ConvertTo-Pester4Result
            $result.Version | Verify-Equal "4.99.0"
        }
    }

    b "Script variables do not leak in between containers" {
        t "Script scoped variables do not leak to next scriptblock" {

            $sb1 = {
                $script:v1 = "v1"
                Describe "d1" {
                    BeforeAll {
                        $script:v2 = "v2"
                    }
                    It "i1" {
                        Get-Variable -Name "v1" -Scope Script -ValueOnly -ErrorAction Ignore | Should -BeNullOrEmpty
                        Get-Variable -Name "v2" -Scope Script -ValueOnly -ErrorAction Ignore | Should -Be "v2"
                    }
                }
            }

            $sb2 = {
                Describe "d1" {
                    It "i1" {
                        Get-Variable -Name "v1" -Scope Script -ValueOnly -ErrorAction Ignore | Should -BeNullOrEmpty
                        Get-Variable -Name "v2" -Scope Script -ValueOnly -ErrorAction Ignore | Should -BeNullOrEmpty
                    }
                }
            }

            $result = Invoke-Pester -Container (New-PesterContainer -ScriptBlock $sb1, $sb2) -PassThru
            $result.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $result.Containers[1].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
        }

        t "Script scoped variables defined in discovery do not leak to next scriptblock" {

            $sb1 = {
                $script:v1 = "v1"
                Describe "d1" {
                    BeforeAll {
                        $script:v2 = "v2"
                    }
                    It "i1" {
                        Get-Variable -Name "v1" -Scope Script -ValueOnly -ErrorAction Ignore | Should -BeNullOrEmpty
                        Get-Variable -Name "v2" -Scope Script -ValueOnly -ErrorAction Ignore | Should -Be "v2"
                    }
                }
            }

            $sb2 = {
                if ($null -ne (Get-Variable -Name "v1" -Scope Script -ValueOnly -ErrorAction Ignore)) {
                    throw "v1 leaked into discovery"
                }
                Describe "d1" {
                    It "i1" {
                    }
                }
            }


            $result = Invoke-Pester -Container (New-PesterContainer -ScriptBlock $sb1, $sb2) -PassThru
            if ($null -eq $result) {
                throw "Run failed, variable leaked into discovery."
            }
            $result.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $result.Containers[1].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
        }

    }

    b "Pester can throw on failed run" {
        t "Exception is thrown" {

            $sb1 = {
                Describe "d1" {
                    It "i1" {
                        1 | Should -Be 0
                    }

                    It "i2" {
                        1 | Should -Be 0
                    }
                }

                Describe "d2" {
                    BeforeAll {
                        throw "fail block in Run"
                    }

                    It "i3" {
                        1 | Should -Be 1
                    }
                }

                Describe "d3" {
                    throw "fail block in Discovery"
                }
            }

            $sb2 = {
                throw "fail container"
            }


            $result = try {
                $c = @{
                    Run = @{
                        ScriptBlock = $sb1, $sb2
                        PassThru    = $true
                        Throw       = $true
                    }
                }

                Invoke-Pester -Configuration $c
            }
            catch {
                $err = $_
            }

            # result should be passed before throwing
            $result | Verify-NotNull
            $err | Verify-Equal "Pester run failed, because 3 tests failed, 1 block failed and 2 containers failed"
        }
    }

    b "Run.SkipRemainingOnFailure" {

        t "Default behavior of running every test after a failure" {
            $sb = {
                Describe "a" {
                    It "b" {
                        $false | Should -BeTrue
                    }
                    It "c" {
                        $true | Should -BeTrue
                    }
                    It "d" {
                        $true | Should -BeTrue
                    }
                }
            }

            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock            = $sb
                    PassThru               = $true
                    SkipRemainingOnFailure = 'None'
                }
                Output = @{
                    CIFormat = 'None'
                }
            }

            $r = Invoke-Pester -Configuration $c

            $r.Containers[0].Blocks[0].Tests[0].Skipped | Verify-False
            $r.Containers[0].Blocks[0].Tests[0].Passed | Verify-False

            $r.Containers[0].Blocks[0].Tests[1].Skipped | Verify-False
            $r.Containers[0].Blocks[0].Tests[1].Passed | Verify-True

            $r.Containers[0].Blocks[0].Tests[2].Skipped | Verify-False
            $r.Containers[0].Blocks[0].Tests[2].Passed | Verify-True
        }

        t "Test is skipped after first failure inside block" {
            $sb = {
                Describe "a" {
                    It "b" {
                        $false | Should -BeTrue
                    }
                    It "c" {
                        $true | Should -BeTrue
                    }
                }
            }

            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock            = $sb
                    PassThru               = $true
                    SkipRemainingOnFailure = 'Block'
                }
                Output = @{
                    CIFormat = 'None'
                }
            }

            $r = Invoke-Pester -Configuration $c

            $r.Containers[0].Blocks[0].Tests[0].Skipped | Verify-False
            $r.Containers[0].Blocks[0].Tests[0].Passed | Verify-False
            $r.Containers[0].Blocks[0].Tests[0].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterAssertionFailed'

            $r.Containers[0].Blocks[0].Tests[1].Skipped | Verify-True
            $r.Containers[0].Blocks[0].Tests[1].Passed | Verify-True
            $r.Containers[0].Blocks[0].Tests[1].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterTestSkipped'
            $r.Containers[0].Blocks[0].Tests[1].ErrorRecord.TargetObject.Message | Verify-Equal "Skipped due to previous failure at 'a.b' and Run.SkipRemainingOnFailure set to 'Block'"
        }

        t "Tests are skipped after first failure inside block for multiple scriptblocks" {
            $sb1 = {
                Describe "a" {
                    It "b" {
                        $false | Should -BeTrue
                    }
                    It "c" {
                        $true | Should -BeTrue
                    }
                }
            }

            $sb2 = {
                Describe "d" {
                    It "e" {
                        $false | Should -BeTrue
                    }
                    It "f" {
                        $true | Should -BeTrue
                    }
                }
            }

            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock            = $sb1, $sb2
                    PassThru               = $true
                    SkipRemainingOnFailure = 'Block'
                }
                Output = @{
                    CIFormat = 'None'
                }
            }

            $r = Invoke-Pester -Configuration $c

            $r.Containers[0].Blocks[0].Tests[0].Skipped | Verify-False
            $r.Containers[0].Blocks[0].Tests[0].Passed | Verify-False
            $r.Containers[0].Blocks[0].Tests[0].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterAssertionFailed'

            $r.Containers[0].Blocks[0].Tests[1].Skipped | Verify-True
            $r.Containers[0].Blocks[0].Tests[1].Passed | Verify-True
            $r.Containers[0].Blocks[0].Tests[1].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterTestSkipped'
            $r.Containers[0].Blocks[0].Tests[1].ErrorRecord.TargetObject.Message | Verify-Equal "Skipped due to previous failure at 'a.b' and Run.SkipRemainingOnFailure set to 'Block'"

            $r.Containers[1].Blocks[0].Tests[0].Skipped | Verify-False
            $r.Containers[1].Blocks[0].Tests[0].Passed | Verify-False
            $r.Containers[1].Blocks[0].Tests[0].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterAssertionFailed'

            $r.Containers[1].Blocks[0].Tests[1].Skipped | Verify-True
            $r.Containers[1].Blocks[0].Tests[1].Passed | Verify-True
            $r.Containers[1].Blocks[0].Tests[1].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterTestSkipped'
            $r.Containers[1].Blocks[0].Tests[1].ErrorRecord.TargetObject.Message | Verify-Equal "Skipped due to previous failure at 'd.e' and Run.SkipRemainingOnFailure set to 'Block'"
        }

        t "Child tests are skipped after first failure inside parent block" {
            $sb = {
                Describe "a" {
                    It "b" {
                        $false | Should -BeTrue
                    }
                    It "c" {
                        $true | Should -BeTrue
                    }
                    Context "d" {
                        It "e" {
                            $true | Should -BeTrue
                        }
                    }
                }
            }

            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock            = $sb
                    PassThru               = $true
                    SkipRemainingOnFailure = 'Block'
                }
                Output = @{
                    CIFormat = 'None'
                }
            }

            $r = Invoke-Pester -Configuration $c

            $r.Containers[0].Blocks[0].Tests[0].Skipped | Verify-False
            $r.Containers[0].Blocks[0].Tests[0].Passed | Verify-False
            $r.Containers[0].Blocks[0].Tests[0].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterAssertionFailed'

            $r.Containers[0].Blocks[0].Tests[1].Skipped | Verify-True
            $r.Containers[0].Blocks[0].Tests[1].Passed | Verify-True
            $r.Containers[0].Blocks[0].Tests[1].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterTestSkipped'
            $r.Containers[0].Blocks[0].Tests[1].ErrorRecord.TargetObject.Message | Verify-Equal "Skipped due to previous failure at 'a.b' and Run.SkipRemainingOnFailure set to 'Block'"

            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].Skipped | Verify-True
            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].Passed | Verify-True
            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterTestSkipped'
            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].ErrorRecord.TargetObject.Message | Verify-Equal "Skipped due to previous failure at 'a.b' and Run.SkipRemainingOnFailure set to 'Block'"
        }

        t "Tests outside of block are not skipped after first failure inside block" {
            $sb = {
                Describe "a" {
                    It "b" {
                        $false | Should -BeTrue
                    }
                }

                Describe "f" {
                    It "g" {
                        $true | Should -BeTrue
                    }
                }
            }

            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock            = $sb
                    PassThru               = $true
                    SkipRemainingOnFailure = 'Block'
                }
                Output = @{
                    CIFormat = 'None'
                }
            }

            $r = Invoke-Pester -Configuration $c

            $r.Containers[0].Blocks[0].Tests[0].Skipped | Verify-False
            $r.Containers[0].Blocks[0].Tests[0].Passed | Verify-False
            $r.Containers[0].Blocks[0].Tests[0].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterAssertionFailed'

            $r.Containers[0].Blocks[1].Tests[0].Skipped | Verify-False
            $r.Containers[0].Blocks[1].Tests[0].Passed | Verify-True
        }

        t "Tests inside container are all skipped after first failure" {
            $sb = {
                Describe "a" {
                    It "b" {
                        $false | Should -BeTrue
                    }
                    It "c" {
                        $true | Should -BeTrue
                    }
                    Context "d" {
                        It "e" {
                            $true | Should -BeTrue
                        }
                    }
                }

                Describe "f" {
                    It "g" {
                        $true | Should -BeTrue
                    }
                }
            }

            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock            = $sb
                    PassThru               = $true
                    SkipRemainingOnFailure = 'Container'
                }
                Output = @{
                    CIFormat = 'None'
                }
            }

            $r = Invoke-Pester -Configuration $c

            $r.Containers[0].Blocks[0].Tests[0].Skipped | Verify-False
            $r.Containers[0].Blocks[0].Tests[0].Passed | Verify-False
            $r.Containers[0].Blocks[0].Tests[0].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterAssertionFailed'

            $r.Containers[0].Blocks[0].Tests[1].Skipped | Verify-True
            $r.Containers[0].Blocks[0].Tests[1].Passed | Verify-True
            $r.Containers[0].Blocks[0].Tests[1].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterTestSkipped'
            $r.Containers[0].Blocks[0].Tests[1].ErrorRecord.TargetObject.Message | Verify-Equal "Skipped due to previous failure at 'a.b' and Run.SkipRemainingOnFailure set to 'Container'"

            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].Skipped | Verify-True
            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].Passed | Verify-True
            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterTestSkipped'
            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].ErrorRecord.TargetObject.Message | Verify-Equal "Skipped due to previous failure at 'a.b' and Run.SkipRemainingOnFailure set to 'Container'"

            $r.Containers[0].Blocks[1].Tests[0].Skipped | Verify-True
            $r.Containers[0].Blocks[1].Tests[0].Passed | Verify-True
            $r.Containers[0].Blocks[1].Tests[0].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterTestSkipped'
            $r.Containers[0].Blocks[1].Tests[0].ErrorRecord.TargetObject.Message | Verify-Equal "Skipped due to previous failure at 'a.b' and Run.SkipRemainingOnFailure set to 'Container'"
        }

        t "Tests inside container are all skipped after first failure for multiple scriptblocks" {
            $sb1 = {
                Describe "a" {
                    It "b" {
                        $false | Should -BeTrue
                    }
                    It "c" {
                        $true | Should -BeTrue
                    }
                    Context "d" {
                        It "e" {
                            $true | Should -BeTrue
                        }
                    }
                }

                Describe "f" {
                    It "g" {
                        $true | Should -BeTrue
                    }
                }
            }

            $sb2 = {
                Describe "h" {
                    It "i" {
                        $false | Should -BeTrue
                    }
                    It "j" {
                        $true | Should -BeTrue
                    }
                    Context "l" {
                        It "m" {
                            $true | Should -BeTrue
                        }
                    }
                }

                Describe "n" {
                    It "o" {
                        $true | Should -BeTrue
                    }
                }
            }

            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock            = $sb1, $sb2
                    PassThru               = $true
                    SkipRemainingOnFailure = 'Container'
                }
                Output = @{
                    CIFormat = 'None'
                }
            }

            $r = Invoke-Pester -Configuration $c

            $r.Containers[0].Blocks[0].Tests[0].Skipped | Verify-False
            $r.Containers[0].Blocks[0].Tests[0].Passed | Verify-False
            $r.Containers[0].Blocks[0].Tests[0].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterAssertionFailed'

            $r.Containers[0].Blocks[0].Tests[1].Skipped | Verify-True
            $r.Containers[0].Blocks[0].Tests[1].Passed | Verify-True
            $r.Containers[0].Blocks[0].Tests[1].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterTestSkipped'
            $r.Containers[0].Blocks[0].Tests[1].ErrorRecord.TargetObject.Message | Verify-Equal "Skipped due to previous failure at 'a.b' and Run.SkipRemainingOnFailure set to 'Container'"

            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].Skipped | Verify-True
            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].Passed | Verify-True
            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterTestSkipped'
            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].ErrorRecord.TargetObject.Message | Verify-Equal "Skipped due to previous failure at 'a.b' and Run.SkipRemainingOnFailure set to 'Container'"

            $r.Containers[0].Blocks[1].Tests[0].Skipped | Verify-True
            $r.Containers[0].Blocks[1].Tests[0].Passed | Verify-True
            $r.Containers[0].Blocks[1].Tests[0].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterTestSkipped'
            $r.Containers[0].Blocks[1].Tests[0].ErrorRecord.TargetObject.Message | Verify-Equal "Skipped due to previous failure at 'a.b' and Run.SkipRemainingOnFailure set to 'Container'"

            $r.Containers[1].Blocks[0].Tests[0].Skipped | Verify-False
            $r.Containers[1].Blocks[0].Tests[0].Passed | Verify-False
            $r.Containers[1].Blocks[0].Tests[0].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterAssertionFailed'

            $r.Containers[1].Blocks[0].Tests[1].Skipped | Verify-True
            $r.Containers[1].Blocks[0].Tests[1].Passed | Verify-True
            $r.Containers[1].Blocks[0].Tests[1].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterTestSkipped'
            $r.Containers[1].Blocks[0].Tests[1].ErrorRecord.TargetObject.Message | Verify-Equal "Skipped due to previous failure at 'h.i' and Run.SkipRemainingOnFailure set to 'Container'"

            $r.Containers[1].Blocks[0].Blocks[0].Tests[0].Skipped | Verify-True
            $r.Containers[1].Blocks[0].Blocks[0].Tests[0].Passed | Verify-True
            $r.Containers[1].Blocks[0].Blocks[0].Tests[0].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterTestSkipped'
            $r.Containers[1].Blocks[0].Blocks[0].Tests[0].ErrorRecord.TargetObject.Message | Verify-Equal "Skipped due to previous failure at 'h.i' and Run.SkipRemainingOnFailure set to 'Container'"

            $r.Containers[1].Blocks[1].Tests[0].Skipped | Verify-True
            $r.Containers[1].Blocks[1].Tests[0].Passed | Verify-True
            $r.Containers[1].Blocks[1].Tests[0].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterTestSkipped'
            $r.Containers[1].Blocks[1].Tests[0].ErrorRecord.TargetObject.Message | Verify-Equal "Skipped due to previous failure at 'h.i' and Run.SkipRemainingOnFailure set to 'Container'"
        }

        t "Tests inside run with multiple scriptblocks are all skipped after first failure" {
            $sb1 = {
                Describe "a" {
                    It "b" {
                        $false | Should -BeTrue
                    }
                    It "c" {
                        $true | Should -BeTrue
                    }
                    Context "d" {
                        It "e" {
                            $true | Should -BeTrue
                        }
                    }
                }
            }

            $sb2 = {
                Describe "f" {
                    It "g" {
                        $true | Should -BeTrue
                    }
                }
            }

            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock            = $sb1, $sb2
                    PassThru               = $true
                    SkipRemainingOnFailure = 'Run'
                }
                Output = @{
                    CIFormat = 'None'
                }
            }

            $r = Invoke-Pester -Configuration $c

            $r.Containers[0].Blocks[0].Tests[0].Skipped | Verify-False
            $r.Containers[0].Blocks[0].Tests[0].Passed | Verify-False
            $r.Containers[0].Blocks[0].Tests[0].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterAssertionFailed'

            $r.Containers[0].Blocks[0].Tests[1].Skipped | Verify-True
            $r.Containers[0].Blocks[0].Tests[1].Passed | Verify-True
            $r.Containers[0].Blocks[0].Tests[1].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterTestSkipped'
            $r.Containers[0].Blocks[0].Tests[1].ErrorRecord.TargetObject.Message | Verify-Equal "Skipped due to previous failure at 'a.b' and Run.SkipRemainingOnFailure set to 'Run'"

            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].Skipped | Verify-True
            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].Passed | Verify-True
            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterTestSkipped'
            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].ErrorRecord.TargetObject.Message | Verify-Equal "Skipped due to previous failure at 'a.b' and Run.SkipRemainingOnFailure set to 'Run'"

            $r.Containers[1].Blocks[0].Tests[0].Skipped | Verify-True
            $r.Containers[1].Blocks[0].Tests[0].Passed | Verify-True
            $r.Containers[1].Blocks[0].Tests[0].ErrorRecord.FullyQualifiedErrorID | Verify-Equal 'PesterTestSkipped'
            $r.Containers[1].Blocks[0].Tests[0].ErrorRecord.TargetObject.Message | Verify-Equal "Skipped due to previous failure at 'a.b' and Run.SkipRemainingOnFailure set to 'Run'"
        }

        foreach ($mode in 'Block', 'Container', 'Run') {
            t "Ignore tests with -Skip or excluded by filter in mode '$mode'" {
                $sb1 = {
                    Describe 'a' {
                        It 'Included - fails' -Tag 'Demo' {
                            $false | Should -BeTrue
                        }
                        It 'Excluded - ignore' {
                            $true | Should -BeTrue
                        }
                        Describe 'b' {
                            It 'Included - skip' -Tag 'Demo' {
                                $true | Should -BeTrue
                            }
                            It 'Included but skipped - ignore' -Tag 'Demo' -Skip {
                                $true | Should -BeTrue
                            }
                        }
                    }
                    Describe 'c' {
                        It 'Included - skip on Container and Run' -Tag 'Demo' {
                            $true | Should -BeTrue
                        }
                    }
                }

                $sb2 = {
                    Describe 'd' {
                        It 'Included - skip on Run' -Tag 'Demo' {
                            $true | Should -BeTrue
                        }
                    }
                }

                $c = [PesterConfiguration] @{
                    Filter = @{
                        Tag = 'Demo'
                    }
                    Run    = @{
                        ScriptBlock            = $sb1, $sb2
                        PassThru               = $true
                        SkipRemainingOnFailure = $mode
                    }
                    Output = @{
                        CIFormat = 'None'
                    }
                }

                $r = Invoke-Pester -Configuration $c

                $r.Tests[0].Skipped | Verify-False
                $r.Tests[0].Result | Verify-Equal 'Failed'

                # Should not mark excluded tests as Skipped
                $r.Tests[1].Skipped | Verify-False
                $r.Tests[1].Result | Verify-Equal 'NotRun'

                # Should mark included test as Skipped
                $r.Tests[2].Skipped | Verify-True
                $r.Tests[2].Result | Verify-Equal 'Skipped'
                $r.Tests[2].ErrorRecord.TargetObject.Message -match '^Skipped due to previous failure' | Verify-True

                # Should not modify explicitly skipped tests
                $r.Tests[3].Skipped | Verify-True
                $r.Tests[3].Result | Verify-Equal 'Skipped'
                $r.Tests[3].ErrorRecord | Verify-Null

                switch ($mode) {
                    'Block' { $r.PluginConfiguration.SkipRemainingOnFailureCount | Verify-Equal 1 }
                    'Container' { $r.PluginConfiguration.SkipRemainingOnFailureCount | Verify-Equal 2 }
                    'Run' { $r.PluginConfiguration.SkipRemainingOnFailureCount | Verify-Equal 3 }
                }
            }
        }

        foreach ($mode in 'Block', 'Container', 'Run') {
            t "Remaining blocks are skipped in mode '$mode'" {
                $container = [ordered]@{
                    RootBeforeAll  = 0
                    RootAfterAll   = 0
                    BlockBeforeAll = 0
                    BlockAfterAll  = 0
                }

                $sb1 = {
                    BeforeAll { $container.RootBeforeAll++ }
                    AfterAll { $container.RootAfterAll++ }

                    Describe 'd1' {
                        BeforeAll { $container.BlockBeforeAll++ }
                        AfterAll { $container.BlockAfterAll++ }

                        It 'Fails' { $false | Should -BeTrue }

                        Context 'c1' {
                            BeforeAll { $container.BlockBeforeAll++ }
                            AfterAll { $container.BlockAfterAll++ }
                            It 'Skipped' { $true | Should -BeTrue }
                        }
                    }
                    Describe 'd2' {
                        BeforeAll { $container.BlockBeforeAll++ }
                        AfterAll { $container.BlockAfterAll++ }

                        It 'Skipped' { $true | Should -BeTrue }
                    }
                }

                $sb2 = {
                    BeforeAll { $container.RootBeforeAll++ }
                    AfterAll { $container.RootAfterAll++ }

                    Describe 'd1' {
                        BeforeAll { $container.BlockBeforeAll++ }
                        AfterAll { $container.BlockAfterAll++ }

                        It 'Skipped' { $true | Should -BeTrue }
                    }
                }

                $c = [PesterConfiguration] @{
                    Run    = @{
                        ScriptBlock            = $sb1, $sb2
                        PassThru               = $true
                        SkipRemainingOnFailure = $mode
                    }
                    Output = @{
                        CIFormat = 'None'
                    }
                }

                $r = Invoke-Pester -Configuration $c
                $r.Containers[0].Result | Verify-Equal 'Failed'
                $r.Containers[0].Blocks[0].Result | Verify-Equal 'Failed'
                $r.Containers[0].Blocks[0].Blocks[0].Result | Verify-Equal 'Skipped'

                # AfterAll should always execute for current and parent blocks of the failure
                # BeforeAll and AfterAll should not be executed for remaining children or siblings
                switch ($mode) {
                    'Block' {
                        $r.Containers[0].Blocks[1].Result | Verify-Equal 'Passed'
                        $r.Containers[1].Result | Verify-Equal 'Passed'
                        $r.Containers[1].Blocks[0].Result | Verify-Equal 'Passed'

                        $container.RootBeforeAll | Verify-Equal 2
                        $container.RootAfterAll | Verify-Equal 2
                        $container.BlockBeforeAll | Verify-Equal 3
                        $container.BlockAfterAll | Verify-Equal 3
                    }
                    'Container' {
                        $r.Containers[0].Blocks[1].Result | Verify-Equal 'Skipped'
                        $r.Containers[1].Result | Verify-Equal 'Passed'
                        $r.Containers[1].Blocks[0].Result | Verify-Equal 'Passed'

                        $container.RootBeforeAll | Verify-Equal 2
                        $container.RootAfterAll | Verify-Equal 2
                        $container.BlockBeforeAll | Verify-Equal 2
                        $container.BlockAfterAll | Verify-Equal 2
                    }
                    'Run' {
                        $r.Containers[0].Blocks[1].Result | Verify-Equal 'Skipped'
                        $r.Containers[1].Result | Verify-Equal 'Skipped'
                        $r.Containers[1].Blocks[0].Result | Verify-Equal 'Skipped'

                        $container.RootBeforeAll | Verify-Equal 1
                        $container.RootAfterAll | Verify-Equal 1
                        $container.BlockBeforeAll | Verify-Equal 1
                        $container.BlockAfterAll | Verify-Equal 1
                    }
                }
            }
        }
    }

    b 'Changes to CWD are reverted on exit' {
        t 'PWD is equal before and after running Invoke-Pester' {
            $beforePWD = $pwd.Path

            $sb = {
                Describe 'd' {
                    It 'i' {
                        Set-Location '../'
                        1 | Should -Be 1
                    }
                }
            }

            $container = New-PesterContainer -ScriptBlock $sb
            Invoke-Pester -Container $container -Output None
            $pwd.Path | Verify-Equal $beforePWD
        }
    }

    b 'Unbound scriptblocks' {
        # Would execute in Pester's internal module state
        t 'Throws when provided to Run.ScriptBlock' {
            $sb = [scriptblock]::Create('')
            $conf = New-PesterConfiguration
            $conf.Run.ScriptBlock = $sb
            $conf.Run.Throw = $true
            $conf.Output.CIFormat = 'None'

            $ex = { Invoke-Pester -Configuration $conf } | Verify-Throw
            $ex.Exception.Message | Verify-Like '*Unbound scriptblock*'
        }

        t 'Throws when provided to Run.Container' {
            $c = [Pester.ContainerInfo]::Create()
            $c.Type = 'ScriptBlock'
            $c.Item = [scriptblock]::Create('')
            $c.Data = @{}

            $conf = New-PesterConfiguration
            $conf.Run.Container = $c
            $conf.Run.Throw = $true
            $conf.Output.CIFormat = 'None'

            $ex = { Invoke-Pester -Configuration $conf } | Verify-Throw
            $ex.Exception.Message | Verify-Like '*Unbound scriptblock*'
        }
    }
}
