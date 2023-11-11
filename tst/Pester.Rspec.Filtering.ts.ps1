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
