param ([switch] $PassThru)

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\..\Dependencies\Axiom\Axiom.psm1 -DisableNameChecking

Import-Module $PSScriptRoot\..\Pester.psd1

$global:PesterDebugPreference = @{
    ShowFullErrors         = $true
    WriteDebugMessages     = $false
    WriteDebugMessagesFrom = "Mock"
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

function Verify-PSType {
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Mandatory = $true, Position = 0)]
        [String] $TypeName
    )

    if ($null -eq $TypeName) {
        throw 'TypeName value is $null.'
    }

    if ($null -eq $Actual) {
        throw 'Actual value is $null.'
    }

    if ($TypeName -ne $Actual.PSObject.TypeNames[0]) {
        throw "Expected object have PSTypeName '$TypeName' but it was '$($Actual.PSObject.TypeNames[0])'!"
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

    #         $result.Blocks[0].ErrorRecord | Verify-Null
    #         $result.Blocks[0].Tests.Count | Verify-Equal 10
    #         $result.Blocks[0].Tests[0].Passed | Verify-True
    #     }
    # }

i -PassThru:$PassThru {
    # b General {
    #     dt "All parameters should be on the parameter object even if not passed" {
    #         $result = Invoke-Pester -ScriptBlock { } -Output None

    #         $result | Verify-Property -PropertyName Parameters
    #         $result.Parameters | Verify-Property -PropertyName "Tags"
    #     }
    # }

    b "New-RSpecTestRunObject" {
        dt "Result object shows counts from all containers" {
            try {
                $temp = [IO.Path]::GetTempPath()

                $file1 = @{
                    Path = "$temp/file1.Tests.ps1"
                    Content = {
                        Describe "file1" {
                            It "i1" {
                                1 | Should -Be 2
                            }
                        }
                    }
                }

                $file1.Content | Set-Content -Path $file1.Path

                $result = Invoke-Pester -ScriptBlock {
                    Describe "d1" {
                        It "i1" {
                            1 | Should -Be 1
                        }

                        It "skip this" -Tag "Slow" {
                            1 | Should -Be 1
                        }
                    }
                } -Path $file1.Path -Output None -ExcludeTag "Slow"
            }
            finally {
                Remove-Item -Path $file1.Path
            }

            $result | Verify-PSType "PesterRSpecTestRun"
            $result | Verify-Property "Containers"
            $result.Containers.Count | Verify-Equal 2
            $result.Containers[0] | Verify-PSType "ExecutedBlockContainer"
            $result | Verify-Property "PSBoundParameters"
            $result.PSBoundParameters.Keys.Count | Verify-Equal 4 # ScriptBlock, Path, Output, ExcludeTag
            #TODO?: $result | Verify-Property "Parameters" | Verify-Equal 27 # fully populated list of parameters
            $result.TestsCount | Verify-Equal 3
            $result.Tests | Verify-NotNull
            $result.PassedCount | Verify-Equal 1
            $result.Passed | Verify-NotNull
            $result.FailedCount | Verify-Equal 1
            $result.Failed | Verify-NotNull
            $result.SkippedCount | Verify-Equal 1
            $result.Skipped | Verify-NotNull
        }
    }
}
