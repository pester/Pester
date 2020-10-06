param ([switch] $PassThru)

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

& "$PSScriptRoot\..\build.ps1"
Import-Module $PSScriptRoot\..\bin\Pester.psd1

$global:PesterPreference = @{
    Debug = @{
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
                            @{ Value = 1}
                            @{ Value = 2}
                            @{ Value = 3}
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
                            @{ Value = 1}
                            @{ Value = 2}
                            @{ Value = 3}
                        ) {
                            $true
                        }

                        It "second-it-$id-<value>" -TestCases @(
                            @{ Value = 1}
                            @{ Value = 2}
                            @{ Value = 3}
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
                InScript = $null
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
                        Path = $file1
                        ScriptBlock = { Describe "d1" { It "i1" { $true } } }
                        PassThru = $true
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
                Run = @{ ScriptBlock = $sb; PassThru = $true }
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
                Run = @{ ScriptBlock = $sb; PassThru = $true }
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
                Run = @{ ScriptBlock = $sb; PassThru = $true }
                Should = @{ ErrorAction = 'Continue' }
            })

            $test = $r.Containers[0].Blocks[0].Tests[0]
            $test | Verify-NotNull
            $test.Result | Verify-Equal "Failed"
            $test.ErrorRecord.Count | Verify-Equal 2
        }

        t "Should throws when called outside of Pester" {
            $PesterPreference = [PesterConfiguration]@{ Should = @{ ErrorAction = 'Continue' }}
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

            $container = New-TestContainer -ScriptBlock $sb -Data @(
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

                $container = New-TestContainer -Path $file -Data @{ Value = 1 }
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
                    (New-TestContainer -Path $file -Data @{ Value = 1 })
                    (New-TestContainer -Path $file -Data @{ Value = 2 })
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

                $container = New-TestContainer -Path $file -Data @(
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
                    (New-TestContainer -Path $file1 -Data @(
                        @{ Value = 1 }
                        @{ Value = 2 }
                    ))

                    (New-TestContainer -Path $file2 -Data @(
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
                $container = New-TestContainer -Path $tmp -Data @(
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

                $container = New-TestContainer -Path $file1 -Data @{ Value = 1 }

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
    }

    b "BeforeDiscovery" {
        t "Variables from BeforeDiscovery are defined in scope" {
            $sb = {
                BeforeDiscovery {
                    $tests = 1,2
                }

                foreach ($t in $tests) {
                    Describe "d$t" {
                        It "t$t" -TestCases @{ t = $t} {
                            $t | Should -BeLessOrEqual 2
                        }
                    }
                }
            }

            $container = New-TestContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[1].Tests[0].Result | Verify-Equal "Passed"
        }
    }

    b "Parametric tests" {
        t "Providing data will generate as many Its as there are data sets" {
            $sb = {
                Describe "d" {
                    It "i" {
                    } -TestCases @(@{ Value = 1}, @{ Value  = 2 })
                }
            }

            $container = New-TestContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests.Count | Verify-Equal 2
        }

        t "-ForEach is alias to -TestCases" {
            $sb = {
                Describe "d" {
                    It "i" {
                    } -ForEach @(@{ Value = 1}, @{ Value  = 2 })
                }
            }

            $container = New-TestContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests.Count | Verify-Equal 2
        }

        t "Providing empty or `$null -TestCases will generate nothing" {
            $sb = {
                Describe "d" {
                    It "i" { } -ForEach @()
                }

                Describe "d" {
                    It "i" { } -ForEach $null
                }
            }

            $container = New-TestContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests.Count | Verify-Equal 0
            $r.Containers[0].Blocks[1].Tests.Count | Verify-Equal 0
        }
    }

    b "Parametric blocks" {
        t "Providing data will generate as many blocks as there are data sets" {
            $sb = {
                Describe "d" {
                    It "i" {
                    }
                } -ForEach @(@{ Value = 1}, @{ Value  = 2 })
            }

            $container = New-TestContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru #
            $r.Containers[0].Blocks.Count | Verify-Equal 2
        }

        t "Providing empty or `$null -ForEach will generate nothing" {
            $sb = {
                Describe "d" {
                    It "i" { }
                } -ForEach @()

                Describe "d" {
                    It "i" { }
                } -ForEach $null
            }

            $container = New-TestContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks.Count | Verify-Equal 0
        }

        t "Data will be available in the respective block during Run" {
            $sb = {
                Describe "d" {
                    BeforeAll {
                        if ($Value -notin 1,2) { throw "`$Value should be 1 or 2 but is '$Value'." }
                    }

                    BeforeEach {
                        if ($Value -notin 1,2) { throw "`$Value should be 1 or 2 but is '$Value'." }
                    }

                    It "i" {
                        if ($Value -notin 1,2) { throw "`$Value should be 1 or 2 but is '$Value'." }
                    }

                    AfterEach {
                        if ($Value -notin 1,2) { throw "`$Value should be 1 or 2 but is '$Value'." }
                    }

                    AfterAll {
                        if ($Value -notin 1,2) { throw "`$Value should be 1 or 2 but is '$Value'." }
                    }
                } -ForEach @(@{ Value = 1}, @{ Value  = 2 })
            }

            $container = New-TestContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[1].Tests[0].Result | Verify-Equal "Passed"
        }

        t "`$_ holds the whole hashtable when hastable is used, and it is not overwritten in It" {
            $sb = {
                Describe "d" {
                    BeforeAll {
                        if ($_.Value -notin 1,2) { throw "`$Value should be 1 or 2 but is '$($_.Value)'." }
                    }

                    It "i" {
                        if ($_.Value -notin 1,2) { throw "`$Value should be 1 or 2 but is '$($_.Value)'." }
                    }
                } -ForEach @(@{ Value = 1 }, @{ Value  = 2 })
            }

            $container = New-TestContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[1].Tests[0].Result | Verify-Equal "Passed"
        }

        t "`$_ holds the whole hashtable when hastable is used, and it is overwritten in It if it specifies its own data" {
            $sb = {
                Describe "d" {
                    BeforeAll {
                        if ($_.Value -notin 1,2) { throw "`$Value should be 1 or 2 but is '$($_.Value)'." }
                    }

                    It "i" {
                        if ($_.Value -ne 10) { throw "`$Value should be 10 '$($_.Value)'." }
                    } -ForEach @{ Value = 10 }
                } -ForEach @(@{ Value = 1 }, @{ Value  = 2 })
            }

            $container = New-TestContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[1].Tests[0].Result | Verify-Equal "Passed"
        }

        t "`$_ holds the current item array of any object is used, and it is overwritten in It if it specifies its own data" {
            $sb = {
                Describe "d" {
                    BeforeAll {
                        if ($_ -notin 1,2) { throw "`$Value should be 1 or 2 but is '$_'." }
                    }

                    # maybe a bit unexpected to get the values of TestCases here, but BeforeEach
                    # runs in the same scope as It, so the variables are available there as well
                    BeforeEach {
                        if ($_ -notin 3,4) { throw "`$Value should be 3 or 4 but is '$_'." }
                    }

                    It "i" {
                        if ($_ -notin 3,4) { throw "`$Value should be 3 or 4 but is '$_'." }
                    } -ForEach 3, 4
                } -ForEach 1, 2
            }

            $container = New-TestContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[1].Tests[0].Result | Verify-Equal "Passed"
        }

        t "Data provided to container are accessible in ForEach on each level" {
            $scenarios = @(
                @{
                    Scenario = @{
                        Name = "A"
                        Contexts = @(
                            @{
                                Name = "AA"
                                Examples = @(
                                    @{ User = @{ Name = "Jakub"; Age = 31 } }
                                    @{ User = @{ Name = "Tomas"; Age = 27 } }
                                )
                            }
                            @{
                                Name = "AB"
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
                        Name = "B"
                        Contexts = @{
                            Name = "BB"
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

            $container = New-TestContainer -ScriptBlock $sb -Data $scenarios

            $r = Invoke-Pester -Container $container -PassThru -Output Detailed
            $r.Containers[0].Blocks[0].ExpandedName | Verify-Equal "Scenario - A"
            $r.Containers[0].Blocks[0].Blocks[0].ExpandedName | Verify-Equal "Context - AA"
            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].ExpandedName | Verify-Equal "Example - Jakub with age 31 is less than 35"

            $r.Containers[0].Blocks[0].Blocks[1].ExpandedName | Verify-Equal "Context - AB"
            $r.Containers[0].Blocks[0].Blocks[1].Tests[0].ExpandedName | Verify-Equal "Example - Peter with age 30 is less than 35"
        }

        t "<_> expands to `$_ in Describe and It" {
            $sb = {
                Describe "d <_>" {
                    It "i <_>" { } -ForEach 2
                } -ForEach 1
            }

            $container = New-TestContainer -ScriptBlock $sb
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

            $container = New-TestContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[0].ExpandedName | Verify-Equal "i 1"
            $r.Containers[0].Blocks[0].ExpandedName | Verify-Equal "d 1"
        }

        t "<user.name> expands to `$user.name" {
            $sb = {
                Describe "d <user.name>" {
                    It "i <user.name>" { }
                } -ForEach @(@{User = @{ Name = "Jakub" }})
            }

            $container = New-TestContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[0].ExpandedName | Verify-Equal "i Jakub"
            $r.Containers[0].Blocks[0].ExpandedName | Verify-Equal "d Jakub"
        }

        t "`$variable remains as literal text after expanding" {
            $sb = {
                Describe "d `$abc" {
                    It "i `$abc" { }
                } -ForEach @(@{User = @{ Name = "Jakub" }})
            }

            $container = New-TestContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[0].ExpandedName | Verify-Equal "i `$abc"
            $r.Containers[0].Blocks[0].ExpandedName | Verify-Equal "d `$abc"
        }

        t 'template can be escaped by grave accent' {
            $sb = {
                Describe "d ``<fff``>" {
                    It 'i `<fff`>' { }
                } -ForEach @(@{User = @{ Name = "Jakub" }})
            }

            $container = New-TestContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[0].ExpandedName | Verify-Equal "i `<fff`>"
            $r.Containers[0].Blocks[0].ExpandedName | Verify-Equal "d `<fff`>"
        }

        t 'template evaluates simple code' {
            $sb = {
                Describe "d" {
                    It 'i <user.name> is <user.Name.GetType()>' { }
                } -ForEach @(@{User = @{ Name = "Jakub" }})
            }

            $container = New-TestContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru -Output Detailed
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[0].ExpandedName | Verify-Equal "i Jakub is string"
        }
    }

    b "Should with legacy syntax will throw" {
        dt "Should with legacy syntax will throw" {
            $sb = {
                Describe "d" {
                    It "i" {
                        1 | Should Be 1
                    }
                }
            }

            $container = New-TestContainer -ScriptBlock $sb
            $r = Invoke-Pester -Container $container -PassThru
            $test = $r.Containers[0].Blocks[0].Tests[0]
            $test.Result | Verify-Equal "Failed"
            $test.ErrorRecord[0] -like "*Legacy Should syntax (without dashes) is not supported in Pester 5.*"
        }
    }
}
