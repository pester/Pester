param ([switch] $PassThru)

Get-Module Pester.Runtime, Pester.Utility, P, Pester, Axiom, Stack | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking

Import-Module $PSPesterRoot\src\Pester.psd1

$global:PesterPreference = @{
    Debug = @{
        ShowFullErrors         = $true
        WriteDebugMessages     = $false
        WriteDebugMessagesFrom = "Mock"
        ReturnRawResultObject  = $true
    }
}

function Verify-PathEqual {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        $Actual,
        [Parameter(Mandatory = $true, Position = 0)]
        $Expected
    )

    if ([string]::IsNullOrEmpty($Expected)) {
        throw "Expected is null or empty."
    }

    if ([string]::IsNullOrEmpty($Actual)) {
        throw "Actual is null or empty."
    }

    $e = ($expected -replace "\\",'/').Trim('/')
    $a = ($actual -replace "\\",'/').Trim('/')

    if ($e -ne $a) {
        throw "Expected path '$e' to be equal to '$a'."
    }
}

i -PassThru:$PassThru {
    b "Default configuration" {

        # General configuration
        t "Exit is `$false" {
            [PesterConfiguration]::Default.Run.Exit.Value | Verify-False
        }

        t "Path is string array, with '.'" {
            $value = [PesterConfiguration]::Default.Run.Path.Value

            # do not do $value | Verify-NotNull
            # because nothing will reach the assetion
            Verify-NotNull -Actual $value
            Verify-Type ([string[]]) -Actual $value
            $value.Count | Verify-Equal 1
            $value[0] | Verify-Equal '.'
        }

        t "ScriptBlock is empty ScriptBlock array" {
            $value = [PesterConfiguration]::Default.Run.ScriptBlock.Value

            # do not do $value | Verify-NotNull
            # because nothing will reach the assetion
            Verify-NotNull -Actual $value
            Verify-Type ([ScriptBlock[]]) -Actual $value
            $value.Count | Verify-Equal 0
        }

        t "TestExtension is *.Tests.ps1" {
            [PesterConfiguration]::Default.Run.TestExtension.Value | Verify-Equal ".Tests.ps1"
        }


        # CodeCoverage configuration
        t "CodeCoverage.Enabled is `$false" {
            [PesterConfiguration]::Default.CodeCoverage.Enabled.Value | Verify-False
        }

        t "CodeCoverage.OutputFormat is JaCoCo" {
            [PesterConfiguration]::Default.CodeCoverage.OutputFormat.Value | Verify-Equal JaCoCo
        }

        t "CodeCoverage.OutputPath is coverage.xml" {
            [PesterConfiguration]::Default.CodeCoverage.OutputPath.Value | Verify-Equal "coverage.xml"
        }

        t "CodeCoverage.OutputEncoding is UTF8" {
            [PesterConfiguration]::Default.CodeCoverage.OutputEncoding.Value | Verify-Equal "UTF8"
        }

        t "CodeCoverage.Path is empty array" {
            $value = [PesterConfiguration]::Default.CodeCoverage.Path.Value
            Verify-NotNull $value
            $value.Count | Verify-Equal 0
        }

        t "CodeCoverage.ExcludeTests is `$true" {
            [PesterConfiguration]::Default.CodeCoverage.ExcludeTests.Value | Verify-True
        }

        # TestResult configuration
        t "TestResult.Enabled is `$false" {
            [PesterConfiguration]::Default.TestResult.Enabled.Value | Verify-False
        }

        t "TestResult.OutputFormat is NUnit2.5" {
            [PesterConfiguration]::Default.TestResult.OutputFormat.Value | Verify-Equal "NUnit2.5"
        }

        t "TestResult.OutputPath is testResults.xml" {
            [PesterConfiguration]::Default.TestResult.OutputPath.Value | Verify-Equal "testResults.xml"
        }

        t "TestResult.OutputEncoding is UTF8" {
            [PesterConfiguration]::Default.TestResult.OutputEncoding.Value | Verify-Equal "UTF8"
        }

        t "TestResult.TestSuiteName is Pester" {
            [PesterConfiguration]::Default.TestResult.TestSuiteName.Value | Verify-Equal "Pester"
        }

        # Should configuration
        t "Should.ErrorAction is Stop" {
            [PesterConfiguration]::Default.Should.ErrorAction.Value | Verify-Equal 'Stop'
        }

        # Debug configuration
        t "Debug.ShowFullErrors is `$false" {
            [PesterConfiguration]::Default.Debug.ShowFullErrors.Value | Verify-False
        }

        t "Debug.WriteDebugMessages is `$false" {
            [PesterConfiguration]::Default.Debug.WriteDebugMessages.Value | Verify-False
        }

        t "Debug.WriteDebugMessagesFrom is '*'" {
            [PesterConfiguration]::Default.Debug.WriteDebugMessagesFrom.Value | Verify-Equal '*'
        }

        t "Debug.ShowNavigationMarkers is `$false" {
            [PesterConfiguration]::Default.Debug.ShowNavigationMarkers.Value | Verify-False
        }

        t "Debug.WriteVSCodeMarker is `$false" {
            [PesterConfiguration]::Default.Debug.WriteVSCodeMarker.Value | Verify-False
        }
    }

    b "Assignment" {
        t "ScriptBlockArrayOption can be assigned a single ScriptBlock" {
            $config = [PesterConfiguration]::Default
            $sb = { "sb" }
            $config.Run.ScriptBlock = $sb

            $config.Run.ScriptBlock.Value | Verify-Equal $sb
        }

        t "ScriptBlockArrayOption can be assigned an array of ScriptBlocks" {
            $config = [PesterConfiguration]::Default
            $sb = { "sb" }, { "sb" }
            $config.Run.ScriptBlock = $sb

            Verify-Same $sb[0] -Actual $config.Run.ScriptBlock.Value[0]
            Verify-Same $sb[1] -Actual $config.Run.ScriptBlock.Value[1]
        }

        t "StringArrayOption can be assigned a single String" {
            $config = [PesterConfiguration]::Default
            $path = "C:\"
            $config.Run.Path = $path

            $config.Run.Path.Value | Verify-Equal $path
        }

        t "StringArrayOption can be assigned an array of Strings" {
            $config = [PesterConfiguration]::Default
            $path = "C:\",  "D:\"
            $config.Run.Path = $path

            Verify-Same $path[0] -Actual $config.Run.Path.Value[0]
            Verify-Same $path[1] -Actual $config.Run.Path.Value[1]
        }
    }

    b "Cloning" {
        t "Configuration can be shallow cloned to avoid modifying user values" {
            $user = [PesterConfiguration]::Default
            $user.Output.Verbosity = "Minimal"

            $cloned = [PesterConfiguration]::ShallowClone($user)
            $cloned.Output.Verbosity = "None"

            $user.Output.Verbosity.Value | Verify-Equal "Minimal"
            $cloned.Output.Verbosity.Value | Verify-Equal "None"
        }
    }

    b "Merging" {
        t "configurations can be merged" {
            $user = [PesterConfiguration]::Default
            $user.Output.Verbosity = "Minimal"
            $user.Filter.Tag = "abc"

            $override = [PesterConfiguration]::Default
            $override.Output.Verbosity = "None"
            $override.Run.Path = "C:\test.ps1"

            $result = [PesterConfiguration]::Merge($user, $override)

            $result.Output.Verbosity.Value | Verify-Equal "None"
            $result.Run.Path.Value | Verify-Equal "C:\test.ps1"
            $result.Filter.Tag.Value | Verify-Equal "abc"
        }

        t "merged object is a new instance" {
            $user = [PesterConfiguration]::Default
            $user.Output.Verbosity = "Minimal"

            $override = [PesterConfiguration]::Default
            $override.Output.Verbosity = "None"

            $result = [PesterConfiguration]::Merge($user, $override)

            [object]::ReferenceEquals($override, $result) | Verify-False
            [object]::ReferenceEquals($user, $result) | Verify-False
        }

        t "values are overwritten even if they are set to the same value as default" {
            $user = [PesterConfiguration]::Default
            $user.Output.Verbosity = "Minimal"
            $user.Filter.Tag = "abc"

            $override = [PesterConfiguration]::Default
            $override.Output.Verbosity = [PesterConfiguration]::Default.Output.Verbosity

            $result = [PesterConfiguration]::Merge($user, $override)

            # has the same value as default but was written so it will override
            $result.Output.Verbosity.Value | Verify-Equal "Normal"
            # has value different from default but was not written in override so the
            # override does not touch it
            $result.Filter.Tag.Value | Verify-Equal "abc"
        }
    }

    b "Advanced interface - Run paths"  {
        t "Running from multiple paths" {
            $container1 = "$PSScriptRoot/testProjects/BasicTests/folder1"
            $container2 = "$PSScriptRoot/testProjects/BasicTests/folder2"

            $c = [PesterConfiguration]@{
                Run = @{
                    Path = $container1, $container2
                    PassThru = $true
                }
                Output = @{
                    Verbosity = 'None'
                }
            }

            $r = Invoke-Pester -Configuration $c
            ($r.Containers[0].Path.Directory) | Verify-PathEqual $container1
            ($r.Containers[1].Path.Directory) | Verify-PathEqual $container2
        }

        t "Filtering based on tags" {
            $c = [PesterConfiguration]@{
                Run = @{
                    Path = "$PSScriptRoot/testProjects/BasicTests"
                    PassThru = $true
                }
                Filter = @{
                    ExcludeTag = 'Slow'
                }
                Output = @{
                    Verbosity = 'None'
                }
            }

            $r = Invoke-Pester -Configuration $c
            $tests = $r.Containers.Blocks.Tests

            $allTags = $tests.Tag | where { $null -ne $_ }
            $allTags | Verify-NotNull
            'slow' -in $allTags | Verify-True

            $runTags = ($tests | where { $_.ShouldRun }).Tag
            'slow' -notin $runTags | Verify-True
        }

        t "Filtering test based on line" {
            $c = [PesterConfiguration]@{
                Run = @{
                    Path = "$PSScriptRoot/testProjects/BasicTests"
                    PassThru = $true
                }
                Filter = @{
                    Line = "$PSScriptRoot/testProjects/BasicTests/folder1/file1.Tests.ps1:8"
                }
                Output = @{
                    Verbosity = 'None'
                }
            }

            $r = Invoke-Pester -Configuration $c
            $tests = @($r.Containers.Blocks.Tests | where { $_.ShouldRun })

            $tests.Count | Verify-Equal 1
            $tests[0].Name | Verify-Equal "fails"
        }

        t "Filtering test based on line" {
            $c = [PesterConfiguration]@{
                Run = @{
                    Path = "$PSScriptRoot/testProjects/BasicTests"
                    PassThru = $true
                }
                Filter = @{
                    Line = "$PSScriptRoot/testProjects/BasicTests/folder1/file1.Tests.ps1:3"
                }
                Output = @{
                    Verbosity = 'None'
                }
            }

            $r = Invoke-Pester -Configuration $c
            $tests = @($r.Containers.Blocks.Tests | where { $_.ShouldRun })

            $tests.Count | Verify-Equal 2
            $tests[0].Name | Verify-Equal "passing"
            $tests[1].Name | Verify-Equal "fails"
        }

        t "Filtering test based on name will find the test" {
            $c = [PesterConfiguration]@{
                Run = @{
                    Path = "$PSScriptRoot/testProjects/BasicTests"
                    PassThru = $true
                }
                Filter = @{
                    FullName = "*state tests.passing"
                }
                Output = @{
                    Verbosity = 'None'
                }
            }

            $r = Invoke-Pester -Configuration $c
            $tests = @($r.Containers.Blocks.Tests | where { $_.ShouldRun })

            $tests.Count | Verify-Equal 1
            $tests[0].Name | Verify-Equal "passing"
        }
    }

    b "merging configuration in Invoke-Pester" {
        t "merges pester preference with provided configuration" {
            $PesterPreference = [PesterConfiguration] @{
                Output = @{
                    Verbosity = 'None'
                }
            }

            $sb = {
                Describe "a" {
                    It "b" {}
                }
            }

            $c = [PesterConfiguration] @{
                Run = @{
                    ScriptBlock = $sb
                    PassThru = $true
                }
            }

            $r = Invoke-Pester -Configuration $c
            $r.Configuration.Output.Verbosity.Value  | Verify-Equal 'None'
            $r.Configuration.Run.ScriptBlock.Value | Verify-Equal $sb
        }
    }
}
