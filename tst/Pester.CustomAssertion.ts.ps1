param ([switch] $PassThru, [switch] $NoBuild)

Get-Module P, PTestHelpers, Pester, Axiom | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

if (-not $NoBuild) { & "$PSScriptRoot\..\build.ps1" }
Import-Module $PSScriptRoot\..\bin\Pester.psd1

$global:PesterPreference = [PesterConfiguration] @{
    Output = @{ Verbosity = 'None' }
}

i -PassThru:$PassThru {
    b "Custom Should-* assertions authored with New-ShouldAssertion" {
        # A custom assertion defined the way a user would, using only the public New-ShouldAssertion
        # surface. It is defined in a BeforeAll so it is available to the tests during the run phase.
        $sb = {
            Describe "custom assertion" {
                BeforeAll {
                    function Should-BeAwesome {
                        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
                        [CmdletBinding()]
                        param (
                            [Parameter(Position = 1, ValueFromPipeline = $true)] $Actual,
                            [Parameter(Position = 0)] $Expected = 'Awesome',
                            [string] $Because
                        )
                        $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
                        $Actual = $assert.Actual()
                        if ($Actual -ne $Expected) {
                            $assert.Fail("Expected <expected>,<because> but got <actual>.", @{ Expected = $Expected; Because = $Because })
                        }
                    }
                }

                It "collects every failure" {
                    'lame' | Should-BeAwesome
                    'boring' | Should-BeAwesome
                }
            }
        }

        t "fails on the first failure of a custom assertion by default (hard assertion)" {
            $configuration = [PesterConfiguration]::Default
            $configuration.Run.ScriptBlock = $sb
            $configuration.Run.PassThru = $true
            $configuration.Output.CIFormat = 'None'
            $r = Invoke-Pester -Configuration $configuration

            $err = $r.Containers[0].Blocks[0].Tests[0].ErrorRecord
            $err.Count | Verify-Equal 1
            $err[0].FullyQualifiedErrorId | Verify-Equal 'PesterAssertionFailed'
        }

        t "records every failure of a custom assertion when Should.ErrorAction is Continue (soft assertion)" {
            $configuration = [PesterConfiguration]::Default
            $configuration.Run.ScriptBlock = $sb
            $configuration.Run.PassThru = $true
            $configuration.Should.ErrorAction = 'Continue'
            $configuration.Output.CIFormat = 'None'
            $r = Invoke-Pester -Configuration $configuration

            $err = $r.Containers[0].Blocks[0].Tests[0].ErrorRecord
            $err.Count | Verify-Equal 2
            $err[0].FullyQualifiedErrorId | Verify-Equal 'PesterAssertionFailed'
        }
    }

    b "Custom Should-* assertion honors -ErrorAction on the assertion itself" {
        $sb = {
            Describe "custom assertion" {
                BeforeAll {
                    function Should-BeAwesome {
                        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
                        [CmdletBinding()]
                        param (
                            [Parameter(Position = 1, ValueFromPipeline = $true)] $Actual,
                            [Parameter(Position = 0)] $Expected = 'Awesome',
                            [string] $Because
                        )
                        $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
                        $Actual = $assert.Actual()
                        if ($Actual -ne $Expected) {
                            $assert.Fail("Expected <expected>,<because> but got <actual>.", @{ Expected = $Expected; Because = $Because })
                        }
                    }
                }

                It "stops on -ErrorAction Stop even when config is Continue" {
                    'lame' | Should-BeAwesome -ErrorAction Stop
                    'boring' | Should-BeAwesome
                }
            }
        }

        t "stops at the first failure when the assertion is called with -ErrorAction Stop" {
            $configuration = [PesterConfiguration]::Default
            $configuration.Run.ScriptBlock = $sb
            $configuration.Run.PassThru = $true
            $configuration.Should.ErrorAction = 'Continue'
            $configuration.Output.CIFormat = 'None'
            $r = Invoke-Pester -Configuration $configuration

            $err = $r.Containers[0].Blocks[0].Tests[0].ErrorRecord
            $err.Count | Verify-Equal 1
        }
    }

    b "Custom Should-* assertions imported from a separate module" {
        # What a consumer actually experiences: the assertion ships in its own module (imported here
        # with New-Module | Import-Module the way Import-Module would load a shipped *.psm1) and is
        # used inside a real Invoke-Pester run. The assertion runs in its own module scope but must
        # still reach the running test for failures, mock parameter filters and soft assertions.
        $sb = {
            Describe "custom assertion" {
                BeforeAll {
                    $null = New-Module -Name AwesomeAssertions {
                        function Should-BeAwesome {
                            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
                            [CmdletBinding()]
                            param (
                                [Parameter(Position = 1, ValueFromPipeline = $true)] $Actual,
                                [Parameter(Position = 0)] $Expected = 'Awesome',
                                [string] $Because
                            )
                            $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
                            $Actual = $assert.Actual()
                            if ($Actual -ne $Expected) {
                                $assert.Fail("Expected <expected>,<because> but got <actual>.", @{ Expected = $Expected; Because = $Because })
                            }
                        }
                        Export-ModuleMember -Function Should-BeAwesome
                    } | Import-Module -Force -PassThru

                    function Get-Thing { [CmdletBinding()] param ([string] $Name) 'real' }
                }

                AfterAll {
                    Get-Module AwesomeAssertions | Remove-Module -Force
                }

                It "passes when the imported assertion matches" {
                    'Awesome' | Should-BeAwesome
                }

                It "fails with the authored message when the imported assertion does not match" {
                    'lame' | Should-BeAwesome -Because 'reasons'
                }

                It "reaches a mock parameter filter through the imported assertion (implicit pass)" {
                    Mock Get-Thing -MockWith { 'mocked' } -ParameterFilter { $Name | Should-BeAwesome 'Awesome' }
                    Get-Thing -Name 'Awesome' | Should-BeAwesome 'mocked'
                }
            }
        }

        t "an imported custom assertion passes, fails with its message, and drives a mock filter inside a run" {
            $configuration = [PesterConfiguration]::Default
            $configuration.Run.ScriptBlock = $sb
            $configuration.Run.PassThru = $true
            $configuration.Output.CIFormat = 'None'
            $r = Invoke-Pester -Configuration $configuration

            $tests = $r.Containers[0].Blocks[0].Tests
            $tests[0].Result | Verify-Equal 'Passed'
            $tests[1].Result | Verify-Equal 'Failed'
            $tests[1].ErrorRecord[0].Exception.Message | Verify-Like "*Expected 'Awesome'*because reasons*but got 'lame'.*"
            $tests[2].Result | Verify-Equal 'Passed'
        }

        $softSb = {
            Describe "custom assertion" {
                BeforeAll {
                    $null = New-Module -Name AwesomeAssertions {
                        function Should-BeAwesome {
                            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
                            [CmdletBinding()]
                            param (
                                [Parameter(Position = 1, ValueFromPipeline = $true)] $Actual,
                                [Parameter(Position = 0)] $Expected = 'Awesome',
                                [string] $Because
                            )
                            $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
                            $Actual = $assert.Actual()
                            if ($Actual -ne $Expected) {
                                $assert.Fail("Expected <expected>,<because> but got <actual>.", @{ Expected = $Expected; Because = $Because })
                            }
                        }
                        Export-ModuleMember -Function Should-BeAwesome
                    } | Import-Module -Force -PassThru
                }

                AfterAll {
                    Get-Module AwesomeAssertions | Remove-Module -Force
                }

                It "collects every failure" {
                    'lame' | Should-BeAwesome
                    'boring' | Should-BeAwesome
                }
            }
        }

        t "an imported custom assertion accumulates soft-assertion failures inside a run" {
            $configuration = [PesterConfiguration]::Default
            $configuration.Run.ScriptBlock = $softSb
            $configuration.Run.PassThru = $true
            $configuration.Should.ErrorAction = 'Continue'
            $configuration.Output.CIFormat = 'None'
            $r = Invoke-Pester -Configuration $configuration

            $err = $r.Containers[0].Blocks[0].Tests[0].ErrorRecord
            $err.Count | Verify-Equal 2
            $err[0].FullyQualifiedErrorId | Verify-Equal 'PesterAssertionFailed'
        }
    }
}
