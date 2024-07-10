param ([switch] $PassThru, [switch] $NoBuild)
# excluding this, as it produces errors because errors are processed differently between v4 and v5, but it is still useful to have around to confirm the overall shape of the result object is correct
return (i -PassThru:$PassThru { })

Get-Module P, PTestHelpers, Pester, Axiom | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\PTestHelpers.psm1 -DisableNameChecking

if (-not $NoBuild) { & "$PSScriptRoot\..\build.ps1" }
Import-Module $PSScriptRoot\..\bin\Pester.psd1

function Invoke-Pester4 ($Arguments) {
    $sb = {
        param ($Arguments)
        Get-Module Pester | Remove-Module
        Import-Module Pester -RequiredVersion 4.10.1
        Invoke-Pester @Arguments -PassThru
    }

    Start-Job -ScriptBlock $sb -ArgumentList $Arguments | Wait-Job | Receive-Job
}

i -PassThru:$PassThru {

    b "ConvertTo-PesterLegacyResult" {
        t "Result object is the same in v4 and v5" {
            try {
                $temp = [IO.Path]::GetTempPath().TrimEnd('\\').TrimEnd("/")

                $file1 = @{
                    Path    = "$temp/file1.Tests.ps1"
                    Content = {
                        Describe "d1" {
                            Context "c1" {
                                It "fails" {
                                    1 | Should -Be 2
                                }
                            }
                        }

                        Describe "d2" {
                            Context "c2" {
                                Describe "c3" {
                                    It "passes" {
                                        1 | Should -Be 1
                                    }
                                }
                            }
                        }

                        Describe "df" {
                            AfterAll { throw }
                            It "fails" {
                                1 | Should -Be 2
                            }
                        }
                    }
                }

                $file2 = @{
                    Path    = "$temp/file2.Tests.ps1"
                    Content = {
                        Describe "d1" {
                            It "pass" {
                                1 | Should -Be 1
                            }

                            It "skip" -Skip {
                                1 | Should -Be 1
                            }
                        }

                        Describe "d2" -Tag "Slow" {
                            It "is excluded" {
                                1 | Should -Be 1
                            }
                        }
                    }
                }


                $file1.Content | Set-Content -Path $file1.Path
                $file2.Content | Set-Content -Path $file2.Path

                $old = Invoke-Pester4 -Arguments @{ Path = ($file1.Path, $file2.Path); ExcludeTag = ("Slow", "some"); Show = "None" }

                $new = Invoke-Pester -Path $file1.Path, $file2.Path -ExcludeTag "Slow", "some" -Output None | ConvertTo-Pester4Result

                $o = Get-EquivalencyOption -ExcludePath Time, TestResult, RunspaceId, PSComputerName, PSShowComputerName -ExcludePathsNotOnExpected
                Assert-Equivalent -Expected $old -Actual $new -Options $o
                $new.Time | Verify-NotNull

                $o = Get-EquivalencyOption -ExcludePath Time -ExcludePathsNotOnExpected
                Assert-Equivalent -Expected $old.TestResult[0] -Actual $new.TestResult[0] -Options $o
                $new.TestResult[0].Time | Verify-NotNull
            }
            finally {
                Remove-Item -Path $file1.Path -ErrorAction SilentlyContinue
                Remove-Item -Path $file2.Path -ErrorAction SilentlyContinue
            }
        }
    }
}
