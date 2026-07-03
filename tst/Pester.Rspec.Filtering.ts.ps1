param ([switch] $PassThru, [switch] $NoBuild)

Get-Module P, PTestHelpers, Pester, Axiom | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

if (-not $NoBuild) { & "$PSScriptRoot\..\build.ps1" }
Import-Module $PSScriptRoot\..\bin\Pester.psd1

$global:PesterPreference = @{
    Debug  = @{
        ShowFullErrors         = $true
        WriteDebugMessages     = $true
        WriteDebugMessagesFrom = "*Filter"
    }
    Output = @{ Verbosity = 'None' }
}

i -PassThru:$PassThru {
    b "Filtering on tags" {
        t "Running tests with tag 't' will run if at least one tag on test matches" {
            $sb = {
                Describe "a" {
                    It "b" -Tag "t", "c" { }
                    It "no tag" { }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Filter = @{ Tag = "t" } })

            $r.Containers[0].Blocks[0].Tests[1].Result | Verify-Equal "NotRun"
        }

        t "Running tests with tag 't' will run all tests in the tagged describe" {
            $sb = {
                Describe "a" -Tag "t" {
                    It "b" -Tag "b", "c" { }
                    It "no tag" { }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Filter = @{ Tag = "t" } })

            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[1].Result | Verify-Equal "Passed"
        }

        t "Running tests with tag 't' will run all tests in the tagged describe and child describes" {

            $sb = {
                Describe "a" -Tag "t" {
                    Describe "b" {
                        It "b" -Tag "b", "c" { }
                        It "no tag" { }
                    }
                    It "no tag" { }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Filter = @{ Tag = "t" } })

            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Blocks[0].Tests[1].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
        }

        t "Excluding tests with tag 't' will run will exclude them from run" {
            $sb = {
                Describe "a" {
                    Describe "b" {
                        It "b" -Tag "t", "c" { }
                        It "no tag" { }
                    }
                    It "no tag" { }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Filter = @{ ExcludeTag = "t" } })

            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].Result | Verify-Equal "NotRun"
            $r.Containers[0].Blocks[0].Blocks[0].Tests[1].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
        }

        t "Excluding blocks with tag 't' will run will exclude them from run" {
            $sb = {
                Describe "a" {
                    Describe "b" -Tag "t" {
                        It "b" -Tag "c" { }
                        It "no tag" { }
                    }
                    It "no tag" { }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Filter = @{ ExcludeTag = "t" } })

            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].Result | Verify-Equal "NotRun"
            $r.Containers[0].Blocks[0].Blocks[0].Tests[1].Result | Verify-Equal "NotRun"
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
        }

        t "Excluding blocks with tag 't' in parent will run will exclude them from run" {
            $sb = {
                Describe "a" -Tag "t" {
                    Describe "b" {
                        It "b" -Tag "c" { }
                        It "no tag" { }
                    }
                    It "no tag" { }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Filter = @{ ExcludeTag = "t" } })

            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].Result | Verify-Equal "NotRun"
            $r.Containers[0].Blocks[0].Blocks[0].Tests[1].Result | Verify-Equal "NotRun"
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "NotRun"
        }
    }

    b "Filtering on the 'None' tag (tests without tags)" {
        t "Including 'None' runs tests that have no tags and skips tagged tests" {
            $sb = {
                Describe "a" {
                    It "untagged" { }
                    It "tagged" -Tag "x" { }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Filter = @{ Tag = "None" } })

            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[1].Result | Verify-Equal "NotRun"
        }

        t "Including 'None' does not run an untagged test when a parent block is tagged" {
            $sb = {
                Describe "tagged block" -Tag "x" {
                    It "no own tag" { }
                }
                Describe "untagged block" {
                    It "no tag" { }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Filter = @{ Tag = "None" } })

            # inherited tag from parent block counts, so this test is effectively tagged
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "NotRun"
            $r.Containers[0].Blocks[1].Tests[0].Result | Verify-Equal "Passed"
        }

        t "Including 'None' runs untagged tests nested in untagged blocks" {
            $sb = {
                Describe "a" {
                    Context "b" {
                        It "t" { }
                    }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Filter = @{ Tag = "None" } })

            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
        }

        t "Including 'None' does not force-run tagged siblings inside an untagged block" {
            $sb = {
                Describe "a" {
                    It "untagged" { }
                    It "fast" -Tag "Fast" { }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Filter = @{ Tag = "None" } })

            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[1].Result | Verify-Equal "NotRun"
        }

        t "Including 'None' also matches a test that is literally tagged 'None'" {
            $sb = {
                Describe "a" {
                    It "literal none" -Tag "None" { }
                    It "other" -Tag "x" { }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Filter = @{ Tag = "None" } })

            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[1].Result | Verify-Equal "NotRun"
        }

        t "Including 'None' is case-insensitive" {
            $sb = {
                Describe "a" {
                    It "untagged" { }
                    It "tagged" -Tag "x" { }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Filter = @{ Tag = "nOnE" } })

            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[1].Result | Verify-Equal "NotRun"
        }

        t "Combining 'None' with another tag runs untagged tests and tests with that tag" {
            $sb = {
                Describe "a" {
                    It "untagged" { }
                    It "fast" -Tag "Fast" { }
                    It "slow" -Tag "Slow" { }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Filter = @{ Tag = "None", "Fast" } })

            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[1].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[2].Result | Verify-Equal "NotRun"
        }

        t "Excluding 'None' skips untagged tests and runs tagged tests" {
            $sb = {
                Describe "a" {
                    It "untagged" { }
                    It "tagged" -Tag "x" { }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Filter = @{ ExcludeTag = "None" } })

            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "NotRun"
            $r.Containers[0].Blocks[0].Tests[1].Result | Verify-Equal "Passed"
        }

        t "Excluding 'None' keeps a tagged test inside an untagged block" {
            $sb = {
                Describe "a" {
                    It "fast" -Tag "Fast" { }
                    It "untagged" { }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Filter = @{ ExcludeTag = "None" } })

            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[1].Result | Verify-Equal "NotRun"
        }

        t "Excluding 'None' keeps an untagged test when a parent block is tagged" {
            $sb = {
                Describe "tagged block" -Tag "x" {
                    It "no own tag" { }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Filter = @{ ExcludeTag = "None" } })

            # inherited tag from parent block counts, so this test is not excluded
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
        }

        t "Excluding 'None' also excludes a test that is literally tagged 'None'" {
            $sb = {
                Describe "a" {
                    It "literal none" -Tag "None" { }
                    It "other" -Tag "x" { }
                }
            }
            $r = Invoke-Pester -Configuration ([PesterConfiguration]@{ Run = @{ ScriptBlock = $sb; PassThru = $true }; Filter = @{ ExcludeTag = "None" } })

            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "NotRun"
            $r.Containers[0].Blocks[0].Tests[1].Result | Verify-Equal "Passed"
        }
    }

    b "Running skipped tests explicitly" {
        t "Having a skipped test will skip it" {
            $sb = {
                Describe "a" {
                    Describe "b" {
                        It "b" { }
                        It "skipped" { } -Skip
                    }
                    It "no tag" { }
                }
            }

            $configuration = [PesterConfiguration]::Default
            $configuration.Output.Verbosity = 'None'
            $configuration.Run = @{ ScriptBlock = $sb; PassThru = $true }
            $configuration.Debug.WriteDebugMessages = $true
            $configuration.Debug.WriteDebugMessagesFrom = "*Filter"

            $r = Invoke-Pester -Configuration $configuration
            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Blocks[0].Tests[1].Result | Verify-Equal "Skipped"
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
        }

        t "Including test by line will ignore -Skip on it" {
            $sb = {
                Describe "a" {
                    Describe "b" {
                        It "b" { }
                        It "skipped" { } -Skip
                    }
                    It "no tag" { }
                }
            }

            $configuration = [PesterConfiguration]::Default
            $configuration.Output.Verbosity = 'None'
            $configuration.Run = @{ ScriptBlock = $sb; PassThru = $true }
            $configuration.Filter = @{ Line = "${PSCommandPath}:$($sb.StartPosition.StartLine+4)" }
            $configuration.Debug.WriteDebugMessages = $true
            $configuration.Debug.WriteDebugMessagesFrom = "*Filter"

            $r = Invoke-Pester -Configuration $configuration
            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].Result | Verify-Equal "NotRun"
            $r.Containers[0].Blocks[0].Blocks[0].Tests[1].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "NotRun"
        }

        t "Including block by line will ignore skip on it but not on children" {
            $sb = {
                Describe "a" {
                    Describe "b" -Skip {
                        It "b" { }
                        It "skipped" { } -Skip
                    }

                    Describe "d" -Skip {
                        It "c" { }
                    }
                    It "no tag" { }
                }
            }

            $configuration = [PesterConfiguration]::Default
            $configuration.Output.Verbosity = 'None'
            $configuration.Run = @{ ScriptBlock = $sb; PassThru = $true }
            $configuration.Filter = @{ Line = "${PSCommandPath}:$($sb.StartPosition.StartLine+2)" }
            $configuration.Debug.WriteDebugMessages = $true
            $configuration.Debug.WriteDebugMessagesFrom = "*Filter"

            $r = Invoke-Pester -Configuration $configuration
            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Blocks[0].Tests[1].Result | Verify-Equal "Skipped"
            $r.Containers[0].Blocks[0].Blocks[1].Tests[0].Result | Verify-Equal "NotRun"
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "NotRun"
        }

        t "Including block by line will not ignore -Skip on tests it" {
            $sb = {
                Describe "a" {
                    Describe "b" {
                        It "b" { }
                        It "skipped" { } -Skip
                    }
                    It "no tag" { }
                }
            }

            $configuration = [PesterConfiguration]::Default
            $configuration.Output.Verbosity = 'None'
            $configuration.Run = @{ ScriptBlock = $sb; PassThru = $true }
            $configuration.Filter = @{ Line = "${PSCommandPath}:$($sb.StartPosition.StartLine+2)" }
            $configuration.Debug.WriteDebugMessages = $true
            $configuration.Debug.WriteDebugMessagesFrom = "*Filter"

            $r = Invoke-Pester -Configuration $configuration
            $r.Containers[0].Blocks[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Blocks[0].Tests[1].Result | Verify-Equal "Skipped"
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "NotRun"
        }
    }

    b "filtering based on full name" {
        t "Including test by name will run it" {
            $sb = {
                Describe "a" {
                    It "b" { }
                    It "c" { }
                }
            }

            $configuration = [PesterConfiguration]::Default
            $configuration.Output.Verbosity = 'None'
            $configuration.Run = @{ ScriptBlock = $sb; PassThru = $true }
            $configuration.Filter = @{ FullName = "*b" }
            $configuration.Debug.WriteDebugMessages = $true
            $configuration.Debug.WriteDebugMessagesFrom = "*Filter"

            $r = Invoke-Pester -Configuration $configuration
            $r.Containers[0].Blocks[0].Tests[0].Result | Verify-Equal "Passed"
            $r.Containers[0].Blocks[0].Tests[1].Result | Verify-Equal "NotRun"
        }
    }
}
