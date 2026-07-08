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
}
