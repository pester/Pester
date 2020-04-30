param ([switch] $PassThru)

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

Import-Module $PSScriptRoot/../bin/Pester.psd1


$global:PesterPreference = @{
    Debug = @{
        ShowFullErrors         = $false
        WriteDebugMessages     = $false
        WriteDebugMessagesFrom = "Mock"
        ReturnRawResultObject  = $true
    }
}

function Verify-Property {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Mandatory = $true, Position = 0)]
        [String] $PropertyName,
        [Parameter(Position = 1)]
        $Value
    )

    if ($null -eq $PropertyName) {
        throw 'PropertyName value is $null.'
    }

    if ($null -eq $Actual) {
        throw 'Actual value is $null.'
    }

    if (-not $Actual.PSObject.Properties.Item($PropertyName)) {
        throw "Expected object to have property $PropertyName!"
    }

    if ($null -ne $Value -and $Value -ne $Actual.$PropertyName) {
        throw "Expected property $PropertyName to have value '$Value', but it was '$($Actual.$PropertyName)'!"
    }
}

# template
    # b "<" {
    #     t ">" {
    #         $result = Invoke-Pester -ScriptBlock {
    #             Describe "d1" {
    #                 It "i1" { $true }
    #             }
    #         }

    #         $result.Containers[0].Blocks[0].ErrorRecord | Verify-Null
    #         $result.Containers[0].Blocks[0].Tests.Count | Verify-Equal 10
    #         $result.Containers[0].Blocks[0].Tests[0].Passed | Verify-True
    #     }
    # }

i -PassThru:$PassThru {
    # b General {
    #     t "All parameters should be on the parameter object even if not passed" {
    #         $result = Invoke-Pester -ScriptBlock { } -Output None

    #         $result | Verify-Property -PropertyName Parameters
    #         $result.Parameters | Verify-Property -PropertyName "Tags"
    #     }
    # }

    b "New-RSpecTestRunObject" {
        t "Result object shows counts from all containers" {
            try {
                $temp = [IO.Path]::GetTempPath().TrimEnd('\\').TrimEnd("/")

                $file1 = @{
                    Path = "$temp/file1.Tests.ps1"
                    Content = {
                        Describe "file1" {
                            It "fail" {
                                1 | Should -Be 2
                            }
                        }
                    }
                }

                $file1.Content | Set-Content -Path $file1.Path

                $sb = {
                    Describe "d1" {
                        It "pass" {
                            1 | Should -Be 1
                        }

                        It "skip" -Skip {
                            1 | Should -Be 1
                        }

                        It "not run" -Tag "Slow" {
                            1 | Should -Be 1
                        }
                    }
                }
                $result = Invoke-Pester -Configuration @{
                    Run = @{
                        ScriptBlock = $sb
                        Path = $file1.Path
                        PassThru = $true
                    }
                    Filter = @{ ExcludeTag = "Slow" }
                    Output = @{ Verbosity = "None" }
                }
            }
            finally {
                Remove-Item -Path $file1.Path
            }

            $result | Verify-Property "Containers"
            $result.Containers.Count | Verify-Equal 2

            $result.TotalCount | Verify-Equal 4
            $result.Tests | Verify-NotNull

            $result.PassedCount | Verify-Equal 1
            $result.Passed | Verify-NotNull

            $result.FailedCount | Verify-Equal 1
            $result.Failed | Verify-NotNull

            $result.SkippedCount | Verify-Equal 1
            $result.Skipped | Verify-NotNull

            $result.NotRunCount | Verify-Equal 1
            $result.NotRun | Verify-NotNull

            $result.Duration | Verify-Equal ($result.Containers[0].Duration + $result.Containers[1].Duration)
            $result.UserDuration | Verify-Equal ($result.Containers[0].UserDuration + $result.Containers[1].UserDuration)
            $result.FrameworkDuration | Verify-Equal ($result.Containers[0].FrameworkDuration + $result.Containers[1].FrameworkDuration)
            $result.DiscoveryDuration | Verify-Equal ($result.Containers[0].DiscoveryDuration + $result.Containers[1].DiscoveryDuration)

            $result | Verify-Property "PSBoundParameters"
            $result.PSBoundParameters.Keys.Count | Verify-Equal 1 # Configuration
        }

        t "Result object indicates success when everything works" {
            $sb = {

                Describe "d1" {
                    It "pass" {
                        1 | Should -Be 1
                    }
                }

                Describe "d2" {
                    Describe "d3" {
                        It "pass" {
                            1 | Should -Be 1
                        }
                    }

                    It "pass" {
                        1 | Should -Be 1
                    }
                }

                Describe "d4" {
                    It "pass" {
                        1 | Should -Be 1
                    }
                }
            }

            $result = Invoke-Pester -Configuration @{
                Run = @{
                    ScriptBlock = $sb
                    PassThru = $true
                }
                Output = @{ Verbosity = "None" }
            }


            $result | Verify-Property "Result"
            $result.Result | Verify-Equal "Passed"

            $result | Verify-Property "Containers"
            $result.Containers.Count | Verify-Equal 1
            $result.Containers[0] | Verify-Property "Result"
            $result.Containers[0].Result | Verify-Equal "Passed"

            $result.Containers[0] | Verify-Property "Blocks"
            $result.Containers[0].Blocks.Count | Verify-Equal 3

            $result.Containers[0].Blocks[0].Name | Verify-Equal "d1"
            $result.Containers[0].Blocks[0] | Verify-Property "Result"
            $result.Containers[0].Blocks[0].Result | Verify-Equal "Passed"

            $result.Containers[0].Blocks[1].Name | Verify-Equal "d2"
            $result.Containers[0].Blocks[1] | Verify-Property "Result"
            $result.Containers[0].Blocks[1].Result | Verify-Equal "Passed"

            $result.Containers[0].Blocks[1].Blocks[0].Name | Verify-Equal "d3"
            $result.Containers[0].Blocks[1].Blocks[0] | Verify-Property "Result"
            $result.Containers[0].Blocks[1].Blocks[0].Result | Verify-Equal "Passed"

            $result.Containers[0].Blocks[2].Name | Verify-Equal "d4"
            $result.Containers[0].Blocks[2] | Verify-Property "Result"
            $result.Containers[0].Blocks[2].Result | Verify-Equal "Passed"
        }

        t "Result object indicates failure when AfterAll fails" {
            $sb = {

                Describe "d1" {
                    AfterAll { throw "abc" }
                    It "pass" {
                        1 | Should -Be 1
                    }
                }

                Describe "d2" {
                    Describe "d3" {
                        AfterAll { throw "abc" }
                        It "pass" {
                            1 | Should -Be 1
                        }
                    }

                    It "pass" {
                        1 | Should -Be 1
                    }
                }

                Describe "d4" -Skip {
                    It "pass" {
                        1 | Should -Be 1
                    }
                }

                Describe "d5" -Tag a {
                    It "pass" {
                        1 | Should -Be 1
                    }
                }
            }

            $result = Invoke-Pester -Configuration @{
                Run = @{
                    ScriptBlock = $sb
                    PassThru = $true
                }
                Filter = @{
                    ExcludeTag = "a"
                }
                Output = @{ Verbosity = "None" }
            }

            $result | Verify-Property "Result"
            $result.Result | Verify-Equal "Failed"
            $result | Verify-Property "Version"
            ($result.version -split "-")[0] | Verify-Equal (Get-Module Pester).Version.ToString()
            $result | Verify-Property "FailedBlocksCount"
            $result.FailedBlocksCount | Verify-Equal 2

            $result | Verify-Property "Containers"
            $result.Containers.Count | Verify-Equal 1
            $result.Containers[0] | Verify-Property "Result"
            $result.Containers[0].Result | Verify-Equal "Failed"

            $result.Containers[0] | Verify-Property "Blocks"
            $result.Containers[0].Blocks.Count | Verify-Equal 4

            $result.Containers[0].Blocks[0].Name | Verify-Equal "d1"
            $result.Containers[0].Blocks[0] | Verify-Property "Result"
            $result.Containers[0].Blocks[0].Result | Verify-Equal "Failed"

            $result.Containers[0].Blocks[1].Name | Verify-Equal "d2"
            $result.Containers[0].Blocks[1] | Verify-Property "Result"
            $result.Containers[0].Blocks[1].Result | Verify-Equal "Failed"

            $result.Containers[0].Blocks[1].Blocks[0].Name | Verify-Equal "d3"
            $result.Containers[0].Blocks[1].Blocks[0] | Verify-Property "Result"
            $result.Containers[0].Blocks[1].Blocks[0].Result | Verify-Equal "Failed"

            $result.Containers[0].Blocks[2].Name | Verify-Equal "d4"
            $result.Containers[0].Blocks[2] | Verify-Property "Result"
            $result.Containers[0].Blocks[2].Result | Verify-Equal "Skipped"

            $result.Containers[0].Blocks[3].Name | Verify-Equal "d5"
            $result.Containers[0].Blocks[3] | Verify-Property "Result"
            $result.Containers[0].Blocks[3].Result | Verify-Equal "NotRun"
        }
    }
}
