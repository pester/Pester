param ([switch] $PassThru, [switch] $NoBuild)

Get-Module P, PTestHelpers, Pester, Axiom | Remove-Module

Import-Module $PSScriptRoot\p.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\axiom\Axiom.psm1 -DisableNameChecking
Import-Module $PSScriptRoot\PTestHelpers.psm1 -DisableNameChecking

if (-not $NoBuild) { & "$PSScriptRoot\..\build.ps1" }
Import-Module $PSScriptRoot\..\bin\Pester.psd1

$global:PesterPreference = @{
    Debug = @{
        ShowFullErrors         = $true
        WriteDebugMessages     = $false
        WriteDebugMessagesFrom = 'Mock'
        ReturnRawResultObject  = $true
    }
}

i -PassThru:$PassThru {
    b "Default configuration" {

        # General configuration
        t "Run.Exit is `$false" {
            [PesterConfiguration]::Default.Run.Exit.Value | Verify-False
        }

        t "Run.Path is string array, with '.'" {
            $value = [PesterConfiguration]::Default.Run.Path.Value

            # do not do $value | Verify-NotNull
            # because nothing will reach the assetion
            Verify-NotNull -Actual $value
            Verify-Type ([string[]]) -Actual $value
            $value.Count | Verify-Equal 1
            $value[0] | Verify-Equal '.'
        }

        t "Run.ScriptBlock is empty ScriptBlock array" {
            $value = [PesterConfiguration]::Default.Run.ScriptBlock.Value

            # do not do $value | Verify-NotNull
            # because nothing will reach the assetion
            Verify-NotNull -Actual $value
            Verify-Type ([ScriptBlock[]]) -Actual $value
            $value.Count | Verify-Equal 0
        }

        t "Run.TestExtension is *.Tests.ps1" {
            [PesterConfiguration]::Default.Run.TestExtension.Value | Verify-Equal ".Tests.ps1"
        }

        t "Run.SkipRemainingOnFailure is None" {
            [PesterConfiguration]::Default.Run.SkipRemainingOnFailure.Value | Verify-Equal "None"
        }

        t 'Run.FailOnNullOrEmptyForEach is $true' {
            [PesterConfiguration]::Default.Run.FailOnNullOrEmptyForEach.Value | Verify-Equal $true
        }

        # Output configuration
        t "Output.Verbosity is Normal" {
            [PesterConfiguration]::Default.Output.Verbosity.Value | Verify-Equal "Normal"
        }

        t "Output.Verbosity Minimal is translated to Normal (backwards compat for currently unsupported option)" {
            $p = [PesterConfiguration]::Default
            $p.Output.Verbosity = "Minimal"
            $p.Output.Verbosity.Value | Verify-Equal "Normal"
        }

        t "Output.StackTraceVerbosity is Filtered" {
            [PesterConfiguration]::Default.Output.StackTraceVerbosity.Value | Verify-Equal Filtered
        }

        t "Output.CIFormat is Auto" {
            [PesterConfiguration]::Default.Output.CIFormat.Value | Verify-Equal Auto
        }

        t "Output.CILogLevel is Error" {
            [PesterConfiguration]::Default.Output.CILogLevel.Value | Verify-Equal 'Error'
        }

        t "Output.RenderMode is Auto" {
            [PesterConfiguration]::Default.Output.RenderMode.Value | Verify-Equal 'Auto'
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

        t "TestResult.OutputFormat is NUnitXml" {
            [PesterConfiguration]::Default.TestResult.OutputFormat.Value | Verify-Equal "NUnitXml"
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

        t "Should.DisableV5 is `$false" {
            [PesterConfiguration]::Default.Should.DisableV5.Value | Verify-Equal $false
        }

        # Debug configuration
        t "Debug.ShowFullErrors is `$false" {
            [PesterConfiguration]::Default.Debug.ShowFullErrors.Value | Verify-False
        }

        t "Debug.WriteDebugMessages is `$false" {
            [PesterConfiguration]::Default.Debug.WriteDebugMessages.Value | Verify-False
        }

        # t "Debug.WriteDebugMessagesFrom is '*'" {
        #     [PesterConfiguration]::Default.Debug.WriteDebugMessagesFrom.Value | Verify-Equal '*'
        # }

        t "Debug.ShowNavigationMarkers is `$false" {
            [PesterConfiguration]::Default.Debug.ShowNavigationMarkers.Value | Verify-False
        }

        t "TestDrive.Enabled is `$true" {
            [PesterConfiguration]::Default.TestDrive.Enabled.Value | Verify-True
        }

        t "TestRegistry.Enabled is `$true" {
            [PesterConfiguration]::Default.TestRegistry.Enabled.Value | Verify-True
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
            $path = "C:\", "D:\"
            $config.Run.Path = $path

            Verify-Same $path[0] -Actual $config.Run.Path.Value[0]
            Verify-Same $path[1] -Actual $config.Run.Path.Value[1]
        }
        t "StringArrayOption can be assigned an array of Objects that don't directly cast to a string" {
            $config = [PesterConfiguration]::Default
            $path = (Join-Path $PWD 'foo'), (Join-Path $PWD 'bar')
            $config.Run.Path = $path

            Verify-Same $path[0] -Actual $config.Run.Path.Value[0]
            Verify-Same $path[1] -Actual $config.Run.Path.Value[1]
        }

        t "StringArrayOption can be assigned an System.Management.Automation.PathInfo" {
            $config = [PesterConfiguration]::Default
            $path = Join-Path (Split-Path $PWD) (Split-Path $PWD -Leaf) | Resolve-Path
            $config.Run.Path = $path

            Verify-Equal $path[0].ToString() -Actual $config.Run.Path.Value[0]
        }

        t "StringArrayOption can be assigned an System.Management.Automation.PathInfo in object array" {
            $config = [PesterConfiguration]::Default
            $path = (Join-Path (Split-Path $PWD) (Split-Path $PWD -Leaf) | Resolve-Path), (Join-Path (Split-Path $PWD ) (Split-Path $PWD -Leaf) | Resolve-Path)
            $config.Run.Path = $path

            Verify-Equal $path[0].ToString() -Actual $config.Run.Path.Value[0]
            Verify-Equal $path[1].ToString() -Actual $config.Run.Path.Value[1]
        }

        t "StringArrayOption can be assigned an PSCustomObject from hashtable" {
            $path = Join-Path (Split-Path $PWD) (Split-Path $PWD -Leaf) | Resolve-Path
            $config = [PesterConfiguration]@{ Run = @{ Path = $path } }

            Verify-Equal $path[0].ToString() -Actual $config.Run.Path.Value[0]
        }

        t 'StringArrayOption can be assigned an arraylist' {
            $expectedPaths = [System.Collections.ArrayList]@('one', 'two', 'three')
            $config = [PesterConfiguration]::Default
            $config.Run.Path = $expectedPaths
            $config.Run.Path.Value[0] | Verify-Equal $expectedPaths[0]
            $config.Run.Path.Value[1] | Verify-Equal $expectedPaths[1]
            $config.Run.Path.Value[2] | Verify-Equal $expectedPaths[2]
        }

        t 'StringArrayOption can be assigned an arraylist from hashtable' {
            $expectedPaths = [System.Collections.ArrayList]@('one', 'two', 'three')
            $config = [PesterConfiguration]@{ Run = @{ Path = $expectedPaths } }
            $config.Run.Path.Value[0] | Verify-Equal $expectedPaths[0]
            $config.Run.Path.Value[1] | Verify-Equal $expectedPaths[1]
            $config.Run.Path.Value[2] | Verify-Equal $expectedPaths[2]
        }

        t 'StringArrayOption can be assigned array of FileInfo and DirectoryInfo' {
            $file = Get-Item -Path "$PSScriptRoot/Pester.RSpec.Configuration.ts.ps1"
            $directory = Get-Item -Path "$PSScriptRoot/testProjects"
            $expectedPaths = @('myFile.ps1', $file, $directory)
            $config = [PesterConfiguration]::Default
            $config.Run.Path = $expectedPaths
            $config.Run.Path.Value[0] | Verify-Equal $expectedPaths[0]
            $config.Run.Path.Value[1] | Verify-Equal $expectedPaths[1].FullName
            $config.Run.Path.Value[2] | Verify-Equal $expectedPaths[2].FullName
        }

        t 'StringArrayOption can be assigned array of FileInfo and DirectoryInfo from hashtable' {
            $file = Get-Item -Path "$PSScriptRoot/Pester.RSpec.Configuration.ts.ps1"
            $directory = Get-Item -Path "$PSScriptRoot/testProjects"
            $expectedPaths = @('myFile.ps1', $file, $directory)
            $config = [PesterConfiguration]::Default
            $config.Run.Path = $expectedPaths
            $config.Run.Path.Value[0] | Verify-Equal $expectedPaths[0]
            $config.Run.Path.Value[1] | Verify-Equal $expectedPaths[1].FullName
            $config.Run.Path.Value[2] | Verify-Equal $expectedPaths[2].FullName
        }

        t "StringArrayOption can be assigned PSCustomObjects in object array" {
            $path = (Join-Path (Split-Path $PWD) (Split-Path $PWD -Leaf)), (Join-Path (Split-Path $PWD) (Split-Path $PWD -Leaf)) | Resolve-Path
            $config = [PesterConfiguration]@{ Run = @{ Path = $path } }

            Verify-Equal $path[0].ToString() -Actual $config.Run.Path.Value[0]
            Verify-Equal $path[1].ToString() -Actual $config.Run.Path.Value[1]
        }

        t "DecimalOption can be assigned an int from hashtable" {
            $config = [PesterConfiguration]@{ CodeCoverage = @{ CoveragePercentTarget = [int] 90 } }
            $config.CodeCoverage.CoveragePercentTarget.Value | Verify-Equal 90
        }

        t "DecimalOption can be assigned an double from hashtable" {
            $config = [PesterConfiguration]@{ CodeCoverage = @{ CoveragePercentTarget = [double] 12.34 } }
            $config.CodeCoverage.CoveragePercentTarget.Value | Verify-Equal 12.34
        }

        t "Modifying the private Default property of an option throws" {
            $config = [PesterConfiguration]::Default
            { $config.Run.Path.Default = 'invalid' } | Verify-Throw
        }

        t "Modifying the private Value property of an option throws" {
            $config = [PesterConfiguration]::Default
            { $config.Run.Path.Value = 'invalid' } | Verify-Throw
        }

        t "IsModified returns true after change even if same as default" {
            $config = [PesterConfiguration]::Default
            $config.Run.Path.IsModified | Verify-False
            $config.Run.Path = $config.Run.Path.Default
            $config.Run.Path.IsModified | Verify-True
        }

        t "Assigning null to array option using hashtable does not throw" {
            # https://github.com/pester/Pester/issues/2026
            $config = [PesterConfiguration]@{ Run = @{ Path = $null } }
            $config.Run.Path | Verify-NotNull
        }

        t "Assigning null to string option using hashtable does not throw" {
            $config = [PesterConfiguration]@{ Run = @{ TestExtension = $null } }
            $config.Run.TestExtension | Verify-NotNull
        }

        t "Assigning null to value option using hashtable does not throw" {
            $config = [PesterConfiguration]@{ Run = @{ Exit = $null } }
            $config.Run.Exit.Value | Verify-NotNull
        }

        t "Assigning null to config-section in hashtable does not throw" {
            $config = [PesterConfiguration]@{ Run = $null }
            $config.Run | Verify-NotNull
        }
    }

    b "Cloning" {
        t "Configuration can be shallow cloned to avoid modifying user values" {
            $user = [PesterConfiguration]::Default
            $user.Output.Verbosity = "Normal"
            $user.Output.StackTraceVerbosity = "Filtered"

            $cloned = [PesterConfiguration]::ShallowClone($user)
            $cloned.Output.Verbosity = "None"
            $cloned.Output.StackTraceVerbosity = "None"

            $user.Output.Verbosity.Value | Verify-Equal "Normal"
            $user.Output.StackTraceVerbosity.Value | Verify-Equal "Filtered"

            $cloned.Output.Verbosity.Value | Verify-Equal "None"
            $cloned.Output.StackTraceVerbosity.Value | Verify-Equal "None"
        }
    }

    b "Merging" {
        t "configurations can be merged" {
            $user = [PesterConfiguration]::Default
            $user.Output.Verbosity = "Normal"
            $user.Output.StackTraceVerbosity = "Filtered"
            $user.Filter.Tag = "abc"

            $override = [PesterConfiguration]::Default
            $override.Output.Verbosity = "None"
            $override.Output.StackTraceVerbosity = "None"
            $override.Run.Path = "C:\test.ps1"

            $result = [PesterConfiguration]::Merge($user, $override)

            $result.Output.Verbosity.Value | Verify-Equal "None"
            $result.Output.StackTraceVerbosity.Value | Verify-Equal "None"
            $result.Run.Path.Value | Verify-Equal "C:\test.ps1"
            $result.Filter.Tag.Value | Verify-Equal "abc"
        }

        t "merged object is a new instance" {
            $user = [PesterConfiguration]::Default
            $user.Output.Verbosity = "Normal"
            $user.Output.StackTraceVerbosity = "Filtered"

            $override = [PesterConfiguration]::Default
            $override.Output.Verbosity = "None"
            $override.Output.StackTraceVerbosity = "None"

            $result = [PesterConfiguration]::Merge($user, $override)

            [object]::ReferenceEquals($override, $result) | Verify-False
            [object]::ReferenceEquals($user, $result) | Verify-False
        }

        t "values are overwritten even if they are set to the same value as default" {
            $user = [PesterConfiguration]::Default
            $user.Output.Verbosity = "Diagnostic"
            $user.Output.StackTraceVerbosity = "Full"
            $user.Filter.Tag = "abc"

            $override = [PesterConfiguration]::Default
            $override.Output.Verbosity = [PesterConfiguration]::Default.Output.Verbosity
            $override.Output.StackTraceVerbosity = [PesterConfiguration]::Default.Output.StackTraceVerbosity

            $result = [PesterConfiguration]::Merge($user, $override)

            # has the same value as default but was written so it will override
            $result.Output.Verbosity.Value | Verify-Equal "Normal"
            $result.Output.StackTraceVerbosity.Value | Verify-Equal "Filtered"
            # has value different from default but was not written in override so the
            # override does not touch it
            $result.Filter.Tag.Value | Verify-Equal "abc"
        }

        t 'IsModified returns False after merging two original values' {
            $one = [PesterConfiguration]::Default
            $two = [PesterConfiguration]::Default
            $result = [PesterConfiguration]::Merge($one, $two)

            # has the same value as default but was written so it will override
            $result.Output.Verbosity.Value | Verify-Equal $one.Output.Verbosity.Value
            $result.Output.Verbosity.IsModified | Verify-False
        }
    }

    b "Advanced interface - Run paths" {
        t "Running from multiple paths" {
            $container1 = "$PSScriptRoot/testProjects/BasicTests/folder1"
            $container2 = "$PSScriptRoot/testProjects/BasicTests/folder2"

            $c = [PesterConfiguration]@{
                Run    = @{
                    Path     = $container1, $container2
                    PassThru = $true
                }
                Output = @{
                    Verbosity = 'None'
                }
            }

            $r = Invoke-Pester -Configuration $c
            ($r.Containers[0].Item.Directory) | Verify-PathEqual $container1
            ($r.Containers[1].Item.Directory) | Verify-PathEqual $container2
        }

        t "Filtering based on tags" {
            $c = [PesterConfiguration]@{
                Run    = @{
                    Path     = "$PSScriptRoot/testProjects/BasicTests"
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

        t "Filtering test based on line of It" {
            $c = [PesterConfiguration]@{
                Run    = @{
                    Path     = "$PSScriptRoot/testProjects/BasicTests"
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

        t "Filtering tests based on line of Describe" {
            $c = [PesterConfiguration]@{
                Run    = @{
                    Path     = "$PSScriptRoot/testProjects/BasicTests"
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

            $tests.Count | Verify-Equal 4
            $tests[0].Name | Verify-Equal "passing"
            $tests[1].Name | Verify-Equal "fails"
            $tests[2].Name | Verify-Equal "passing with testcases"
            $tests[3].Name | Verify-Equal "passing with testcases"
        }

        t "Filtering test with testcases based on line of It" {
            $c = [PesterConfiguration]@{
                Run    = @{
                    Path     = "$PSScriptRoot/testProjects/BasicTests"
                    PassThru = $true
                }
                Filter = @{
                    Line = "$PSScriptRoot/testProjects/BasicTests/folder1/file1.Tests.ps1:12"
                }
                Output = @{
                    Verbosity = 'None'
                }
            }

            $r = Invoke-Pester -Configuration $c
            $tests = @($r.Containers.Blocks.Tests | where { $_.ShouldRun })

            $tests.Count | Verify-Equal 2
            $tests[0].Name | Verify-Equal "passing with testcases"
            $tests[0].Data.Value | Verify-Equal 1
            $tests[1].Name | Verify-Equal "passing with testcases"
            $tests[1].Data.Value | Verify-Equal 2
        }

        t "Filtering test based on name will find the test" {
            $c = [PesterConfiguration]@{
                Run    = @{
                    Path     = "$PSScriptRoot/testProjects/BasicTests"
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
                    PassThru    = $true
                }
            }

            $r = Invoke-Pester -Configuration $c
            $r.Configuration.Output.Verbosity.Value  | Verify-Equal 'None'
            $r.Configuration.Run.ScriptBlock.Value | Verify-Equal $sb
        }
    }

    b "configuration modified at runtime" {
        t "changes at runtime doesn't leak to advanced configuration object" {
            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock = { }
                    PassThru    = $true
                }
                Output = @{
                    Verbosity = 'Diagnostic'
                }
                Debug  = @{
                    WriteDebugMessagesFrom = 'Something'
                }
            }

            $r = Invoke-Pester -Configuration $c

            # Diagnostic modifies Debug.WriteDebugMessagesFrom at runtime
            $r.Configuration.Debug.WriteDebugMessagesFrom.Value.Count -gt 1 | Verify-True
            'Something' -eq $c.Debug.WriteDebugMessagesFrom.Value | Verify-True
        }
    }

    b "New-PesterConfiguration" {
        t "Creates default configuration when no parameters are specified" {
            $config = New-PesterConfiguration

            $config | Verify-Type ([PesterConfiguration])
            $config.Run.Path.Value | Verify-Equal $config.Run.Path.Default
            $config.Run.PassThru.Value | Verify-Equal $config.Run.PassThru.Default
        }

        t "Merges configuration when hashtable is provided" {
            $MyOptions = @{
                Run    = @{
                    PassThru = $true
                }
                Filter = @{
                    Tag = "Core"
                }
            }
            $config = New-PesterConfiguration -Hashtable $MyOptions

            $config.Run.PassThru.Value | Verify-Equal $true
            $config.Filter.Tag.Value -contains 'Core' | Verify-True
        }

        t "Merges configuration when hashtable keys are boxed in PSObject" {
            $MyOptions = @{
                Run    = New-Object PSObject -ArgumentList (
                    @{
                        PassThru = $true
                    }
                )
                Filter = New-Object PSObject -ArgumentList (
                    @{
                        Tag = "Core"
                    }
                )
            }

            $config = New-PesterConfiguration -Hashtable $MyOptions

            $config.Run.PassThru.Value | Verify-Equal $true
            $config.Filter.Tag.Value -contains 'Core' | Verify-True
        }

        t 'IsModified is only True on modified properties after merging Hashtable' {
            $MyOptions = @{
                Run    = @{
                    PassThru = $true
                }
                Filter = @{
                    Tag = 'Core'
                }
            }
            $config = New-PesterConfiguration -Hashtable $MyOptions

            $config.Run.PassThru.Value | Verify-Equal $true
            $config.Filter.Tag.Value -contains 'Core' | Verify-True
            $config.Run.PassThru.IsModified | Verify-True
            $config.Run.SkipRun.IsModified | Verify-False
        }

        t "Merges configuration when a hashtable has been serialized" {
            $BeforeSerialization = @{
                Run    = @{
                    PassThru = $true
                }
                Filter = @{
                    Tag = "Core"
                }
            }

            $Serializer = [System.Management.Automation.PSSerializer]
            $AfterSerialization = $Serializer::Deserialize($Serializer::Serialize($BeforeSerialization))
            $config = New-PesterConfiguration -Hashtable $AfterSerialization

            $config.Run.PassThru.Value | Verify-Equal $true
            $config.Filter.Tag.Value -contains 'Core' | Verify-True
            $config.Run.PassThru.IsModified | Verify-True
            $config.Run.SkipRun.IsModified | Verify-False
            $config.Output.Verbosity.IsModified | Verify-False
        }

        t "Merges configuration when a PesterConfiguration object has been serialized" {
            $BeforeSerialization = New-PesterConfiguration -Hashtable @{
                Run    = @{
                    PassThru = $true
                }
                Filter = @{
                    Tag = "Core"
                }
            }

            $Serializer = [System.Management.Automation.PSSerializer]
            $AfterSerialization = $Serializer::Deserialize($Serializer::Serialize($BeforeSerialization))

            $config = [PesterConfiguration]$AfterSerialization

            $config.Run.PassThru.Value | Verify-Equal $true
            $config.Filter.Tag.Value -contains 'Core' | Verify-True
            $config.Run.PassThru.IsModified | Verify-True
            $config.Run.SkipRun.IsModified | Verify-False
            $config.Output.Verbosity.IsModified | Verify-False
        }

        t "Merges configuration when a PesterConfiguration object includes an array of values" {
            $BeforeSerialization = New-PesterConfiguration -Hashtable @{
                Run = @{
                    Path = @(
                        'c:\path1'
                        'c:\path2'
                    )
                }
            }

            $Serializer = [System.Management.Automation.PSSerializer]
            $AfterSerialization = $Serializer::Deserialize($Serializer::Serialize($BeforeSerialization))
            $config = [PesterConfiguration]$AfterSerialization

            $config.Run.Path.Value -join ',' | Verify-Equal 'c:\path1,c:\path2'
        }

        t "Merges configuration when a PesterConfiguration object has been serialized with a ScriptBlock" {
            $BeforeSerialization = New-PesterConfiguration -Hashtable @{
                Run = @{
                    ScriptBlock = {
                        'Hello world'
                    }
                }
            }

            $Serializer = [System.Management.Automation.PSSerializer]
            $AfterSerialization = $Serializer::Deserialize($Serializer::Serialize($BeforeSerialization))
            $config = [PesterConfiguration]$AfterSerialization

            $config.Run.ScriptBlock.Value.GetType() | Verify-Equal ([ScriptBlock[]])
        }

        t "Merges configuration when a PesterConfiguration object has been serialized with a ContainerInfo object" {
            $BeforeSerialization = New-PesterConfiguration -Hashtable @{
                Run = @{
                    Container = @(
                        $container = [Pester.ContainerInfo]::Create()
                        $container.Type = 'File'
                        $container.Item = 'Item'
                        $container.Data = 'Data'
                        $container
                    )
                }
            }

            $Serializer = [System.Management.Automation.PSSerializer]
            $AfterSerialization = $Serializer::Deserialize($Serializer::Serialize($BeforeSerialization))
            $config = [PesterConfiguration]$AfterSerialization

            $config.Run.Container.Value.GetType() | Verify-Equal ([Pester.ContainerInfo[]])
            $config.Run.Container.Value[0].Type | Verify-Equal 'File'
            $config.Run.Container.Value[0].Item | Verify-Equal 'Item'
            $config.Run.Container.Value[0].Data | Verify-Equal 'Data'
        }
    }

    b "Output.StackTraceVerbosity" {
        t "Each option can be set and updated" {
            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock = { }
                    PassThru    = $true
                }
                Debug  = @{
                    ShowFullErrors = $false
                }
                Output = @{
                    Verbosity = "None"
                }
            }

            foreach ($option in "None", "FirstLine", "Filtered", "Full") {
                $c.Output.StackTraceVerbosity = $option
                $r = Invoke-Pester -Configuration $c
                $r.Configuration.Output.StackTraceVerbosity.Value | Verify-Equal $option
            }
        }

        t "Default is Filtered" {
            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock = { }
                    PassThru    = $true
                }
                Debug  = @{
                    ShowFullErrors = $false
                }
                Output = @{
                    Verbosity = "None"
                }
            }

            $r = Invoke-Pester -Configuration $c
            $r.Configuration.Output.StackTraceVerbosity.Value | Verify-Equal "Filtered"
        }

        t "Debug.ShowFullErrors overrides Output.StackTraceVerbosity to Full when set to `$true" {
            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock = { }
                    PassThru    = $true
                }
                Debug  = @{
                    ShowFullErrors = $true
                }
                Output = @{
                    Verbosity = "None"
                }
            }

            $r = Invoke-Pester -Configuration $c
            $r.Configuration.Output.StackTraceVerbosity.Value | Verify-Equal "Full"
        }

        t "Exception is thrown when incorrect option is set" {
            $sb = {
                Describe "a" {
                    It "b" {}
                }
            }

            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock = $sb
                    Throw       = $true
                }
                Debug  = @{
                    ShowFullErrors = $false
                }
                Output = @{
                    StackTraceVerbosity = "Something"
                    CIFormat            = 'None'
                }
            }

            try {
                Invoke-Pester -Configuration $c
            }
            catch {
                $_.Exception.Message -match "Output.StackTraceVerbosity must be .* it was 'Something'" | Verify-True
                $failed = $true
            }
            $failed | Verify-True
        }
    }

    b "Output.CIFormat" {
        t "Output.CIFormat is AzureDevops when Auto(default) and TF_BUILD are set" {
            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock = { }
                    PassThru    = $true
                }
                Output = @{
                    Verbosity = "None"
                }
            }

            $previousTfBuildVariable = $env:TF_BUILD
            $previousGithubActionsVariable = $env:GITHUB_ACTIONS

            $env:TF_BUILD = $true
            $env:GITHUB_ACTIONS = $false

            try {
                $r = Invoke-Pester -Configuration $c
                $r.Configuration.Output.CIFormat.Value | Verify-Equal "AzureDevops"
            }
            finally {
                $env:TF_BUILD = $previousTfBuildVariable
                $env:GITHUB_ACTIONS = $previousGithubActionsVariable
            }
        }

        t "Output.CIFormat is AzureDevops when Auto(manually set) and TF_BUILD are set" {
            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock = { }
                    PassThru    = $true
                }
                Output = @{
                    Verbosity = "None"
                    CIFormat  = "Auto"
                }
            }

            $previousTfBuildVariable = $env:TF_BUILD
            $previousGithubActionsVariable = $env:GITHUB_ACTIONS

            $env:TF_BUILD = $true
            $env:GITHUB_ACTIONS = $false

            try {
                $r = Invoke-Pester -Configuration $c
                $r.Configuration.Output.CIFormat.Value | Verify-Equal "AzureDevops"
            }
            finally {
                $env:TF_BUILD = $previousTfBuildVariable
                $env:GITHUB_ACTIONS = $previousGithubActionsVariable
            }
        }

        t "Output.CIFormat is AzureDevops when AzureDevops(manually set) and TF_BUILD are set" {
            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock = { }
                    PassThru    = $true
                }
                Output = @{
                    Verbosity = "None"
                    CIFormat  = "AzureDevops"
                }
            }

            $previousTfBuildVariable = $env:TF_BUILD
            $previousGithubActionsVariable = $env:GITHUB_ACTIONS

            $env:TF_BUILD = $true
            $env:GITHUB_ACTIONS = $false

            try {
                $r = Invoke-Pester -Configuration $c
                $r.Configuration.Output.CIFormat.Value | Verify-Equal "AzureDevops"
            }
            finally {
                $env:TF_BUILD = $previousTfBuildVariable
                $env:GITHUB_ACTIONS = $previousGithubActionsVariable
            }
        }

        t "Output.CIFormat is None when Auto(default) and TF_BUILD is not set" {
            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock = { }
                    PassThru    = $true
                }
                Output = @{
                    Verbosity = "None"
                }
            }

            $previousTfBuildVariable = $env:TF_BUILD
            $previousGithubActionsVariable = $env:GITHUB_ACTIONS

            $env:TF_BUILD = $false
            $env:GITHUB_ACTIONS = $false

            try {
                $r = Invoke-Pester -Configuration $c
                $r.Configuration.Output.CIFormat.Value | Verify-Equal "None"
            }
            finally {
                $env:TF_BUILD = $previousTfBuildVariable
                $env:GITHUB_ACTIONS = $previousGithubActionsVariable
            }
        }

        t "Output.CIFormat is GithubActions when Auto(default) and GITHUB_ACTIONS are set" {
            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock = { }
                    PassThru    = $true
                }
                Output = @{
                    Verbosity = "None"
                }
            }

            $previousTfBuildVariable = $env:TF_BUILD
            $previousGithubActionsVariable = $env:GITHUB_ACTIONS

            $env:TF_BUILD = $false
            $env:GITHUB_ACTIONS = $true

            try {
                $r = Invoke-Pester -Configuration $c
                $r.Configuration.Output.CIFormat.Value | Verify-Equal "GithubActions"
            }
            finally {
                $env:TF_BUILD = $previousTfBuildVariable
                $env:GITHUB_ACTIONS = $previousGithubActionsVariable
            }
        }

        t "Output.CIFormat is GithubActions when Auto(manually set) and GITHUB_ACTIONS are set" {
            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock = { }
                    PassThru    = $true
                }
                Output = @{
                    Verbosity = "None"
                    CIFormat  = "Auto"
                }
            }

            $previousTfBuildVariable = $env:TF_BUILD
            $previousGithubActionsVariable = $env:GITHUB_ACTIONS

            $env:TF_BUILD = $false
            $env:GITHUB_ACTIONS = $true

            try {
                $r = Invoke-Pester -Configuration $c
                $r.Configuration.Output.CIFormat.Value | Verify-Equal "GithubActions"
            }
            finally {
                $env:TF_BUILD = $previousTfBuildVariable
                $env:GITHUB_ACTIONS = $previousGithubActionsVariable
            }
        }

        t "Output.CIFormat is GithubActions when GithubActions(manually set) and GITHUB_ACTIONS are set" {
            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock = { }
                    PassThru    = $true
                }
                Output = @{
                    Verbosity = "None"
                    CIFormat  = "GithubActions"
                }
            }

            $previousTfBuildVariable = $env:TF_BUILD
            $previousGithubActionsVariable = $env:GITHUB_ACTIONS

            $env:TF_BUILD = $false
            $env:GITHUB_ACTIONS = $true

            try {
                $r = Invoke-Pester -Configuration $c
                $r.Configuration.Output.CIFormat.Value | Verify-Equal "GithubActions"
            }
            finally {
                $env:TF_BUILD = $previousTfBuildVariable
                $env:GITHUB_ACTIONS = $previousGithubActionsVariable
            }
        }

        t "Output.CIFormat is None when Auto(default) and GITHUB_ACTIONS is not set" {
            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock = { }
                    PassThru    = $true
                }
                Output = @{
                    Verbosity = "None"
                }
            }

            $previousTfBuildVariable = $env:TF_BUILD
            $previousGithubActionsVariable = $env:GITHUB_ACTIONS

            $env:TF_BUILD = $false
            $env:GITHUB_ACTIONS = $false

            try {
                $r = Invoke-Pester -Configuration $c
                $r.Configuration.Output.CIFormat.Value | Verify-Equal "None"
            }
            finally {
                $env:TF_BUILD = $previousTfBuildVariable
                $env:GITHUB_ACTIONS = $previousGithubActionsVariable
            }
        }

        t "Exception is thrown when incorrect option is set" {
            $sb = {
                Describe "a" {
                    It "b" {}
                }
            }

            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock = $sb
                    Throw       = $true
                }
                Output = @{
                    CIFormat = "Something"
                }
            }

            try {
                Invoke-Pester -Configuration $c
            }
            catch {
                $_.Exception.Message -match "Output.CIFormat must be .* it was 'Something'" | Verify-True
                $failed = $true
            }
            $failed | Verify-True
        }

        t "Output.CIFormat is None when set" {
            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock = { }
                    PassThru    = $true
                }
                Output = @{
                    Verbosity = "None"
                    CIFormat  = "None"
                }
            }

            $r = Invoke-Pester -Configuration $c
            $r.Configuration.Output.CIFormat.Value | Verify-Equal "None"
        }
    }

    b "Output.CILogLevel" {
        t "Each option can be set and updated" {
            $c = [PesterConfiguration] @{
                Run = @{
                    ScriptBlock = { }
                    PassThru    = $true
                }
            }

            foreach ($option in "Error", "Warning") {
                $c.Output.CILogLevel = $option
                $r = Invoke-Pester -Configuration $c
                $r.Configuration.Output.CILogLevel.Value | Verify-Equal $option
            }
        }

        t "Exception is thrown when incorrect option is set" {
            $sb = {
                Describe "a" {
                    It "b" {}
                }
            }

            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock = $sb
                    PassThru    = $true
                    Throw       = $true
                }
                Output = @{
                    CIFormat   = 'None'
                    CILogLevel = 'Something'
                }
            }

            { Invoke-Pester -Configuration $c } | Verify-Throw
        }
    }

    b 'Output.RenderMode' {
        t 'Output.RenderMode is Plaintext when set to Auto (default) and env:NO_COLOR is set' {
            $c = [PesterConfiguration] @{
                Run = @{
                    ScriptBlock = { }
                    PassThru    = $true
                }
            }

            $previousValue = $env:NO_COLOR
            $env:NO_COLOR = $true

            try {
                $r = Invoke-Pester -Configuration $c
                $r.Configuration.Output.RenderMode.Value | Verify-Equal 'Plaintext'
            }
            finally {
                if ($null -ne $previousValue) { $env:NO_COLOR = $previousValue } else { Remove-Item Env:\NO_COLOR }
            }
        }

        t 'Output.RenderMode is Plaintext when set to Plaintext and env:NO_COLOR is not set' {
            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock = { }
                    PassThru    = $true
                }
                Output = @{
                    RenderMode = 'Plaintext'
                }
            }

            $previousValue = $env:NO_COLOR
            Remove-Item Env:\NO_COLOR -ErrorAction SilentlyContinue

            try {
                $r = Invoke-Pester -Configuration $c
                $r.Configuration.Output.RenderMode.Value | Verify-Equal 'Plaintext'
            }
            finally {
                if ($null -ne $previousValue) { $env:NO_COLOR = $previousValue }
            }
        }

        if ($($VT = $host.UI.psobject.Properties['SupportsVirtualTerminal']) -and $VT.Value) {
            t 'Output.RenderMode is Ansi when set to Auto and virtual terminal is supported and env:NO_COLOR is not set' {
                $c = [PesterConfiguration] @{
                    Run    = @{
                        ScriptBlock = { }
                        PassThru    = $true
                    }
                    Output = @{
                        RenderMode = 'Auto'
                    }
                }

                $previousValue = $env:NO_COLOR
                Remove-Item Env:\NO_COLOR -ErrorAction SilentlyContinue

                try {
                    $r = Invoke-Pester -Configuration $c
                    $r.Configuration.Output.RenderMode.Value | Verify-Equal 'Ansi'
                }
                finally {
                    if ($null -ne $previousValue) { $env:NO_COLOR = $previousValue }
                }
            }
        }

        t 'Output.RenderMode is ConsoleColor when set to Auto and virtual terminal is not supported and env:NO_COLOR is not set' {
            $previousValue = $env:NO_COLOR
            Remove-Item Env:\NO_COLOR -ErrorAction SilentlyContinue

            $pesterPath = Get-Module Pester | Select-Object -ExpandProperty Path
            try {
                $ps = [PowerShell]::Create()
                $ps.AddCommand('Set-StrictMode').AddParameter('Version', 'Latest') > $null
                $ps.AddStatement().AddScript("Import-Module '$pesterPath' -Force") > $null
                $ps.AddStatement().AddScript('$c = [PesterConfiguration]@{Run = @{ScriptBlock={ describe "d1" { it "i1" { } } };PassThru=$true};Output=@{RenderMode="Auto"}}') > $null
                $ps.AddStatement().AddScript('Invoke-Pester -Configuration $c') > $null
                $r = $ps.Invoke()

                "$($ps.Streams.Error)" | Verify-Equal ''
                $ps.HadErrors | Verify-False
                $r.Configuration.Output.RenderMode.Value | Verify-Equal 'ConsoleColor'
            }
            finally {
                $ps.Dispose()
                if ($null -ne $previousValue) { $env:NO_COLOR = $previousValue }
            }
        }

        t 'Each non-Auto option can be set and updated' {
            $c = [PesterConfiguration] @{
                Run = @{
                    ScriptBlock = { }
                    PassThru    = $true
                }
            }

            foreach ($option in 'Ansi', 'ConsoleColor', 'Plaintext') {
                $c.Output.RenderMode = $option
                $r = Invoke-Pester -Configuration $c
                $r.Configuration.Output.RenderMode.Value | Verify-Equal $option
            }
        }

        t 'Exception is thrown when incorrect option is set' {
            $sb = {
                Describe 'a' {
                    It 'b' {}
                }
            }

            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock = $sb
                    Throw       = $true
                }
                Output = @{
                    CIFormat   = 'None'
                    RenderMode = 'Something'
                }
            }

            try {
                Invoke-Pester -Configuration $c
                $true | Verify-False # Should not get here
            }
            catch {
                $_.Exception.Message -match "Output.RenderMode must be .* it was 'Something'" | Verify-True
                $failed = $true
            }
            $failed | Verify-True
        }
    }

    b "Run.SkipRemainingOnFailure" {
        t "Each option can be set and updated" {
            $c = [PesterConfiguration] @{
                Run = @{
                    ScriptBlock = { }
                    PassThru    = $true
                }
            }

            foreach ($option in "None", "Block", "Container", "Run") {
                $c.Run.SkipRemainingOnFailure = $option
                $r = Invoke-Pester -Configuration $c
                $r.Configuration.Run.SkipRemainingOnFailure.Value | Verify-Equal $option
            }
        }

        t "Exception is thrown when incorrect option is set" {
            $sb = {
                Describe "a" {
                    It "b" {}
                }
            }

            $c = [PesterConfiguration] @{
                Run    = @{
                    ScriptBlock            = $sb
                    PassThru               = $true
                    SkipRemainingOnFailure = 'Something'
                    Throw                  = $true
                }
                Output = @{
                    CIFormat = 'None'
                }
            }

            { Invoke-Pester -Configuration $c } | Verify-Throw
        }
    }

    b "Should.DisableV5" {
        t "Disabling V5 assertions makes Should -Be throw" {
            $c = [PesterConfiguration]@{
                Run    = @{
                    ScriptBlock = { Describe 'a' { It 'b' { 1 | Should -Be 1 } } }
                    PassThru    = $true
                }
                Should = @{
                    DisableV5 = $true
                }
                Output = @{
                    CIFormat = 'None'
                }
            }

            $r = Invoke-Pester -Configuration $c
            $err = $r.Containers.Blocks.Tests.ErrorRecord

            $err.Exception.Message | Verify-Equal 'Pester Should -Be syntax is disabled. Use Should-Be (without space), or enable it by setting: $PesterPreference.Should.DisableV5 = $false'
        }

        t "Enabling V5 assertions makes Should -Be pass" {
            $c = [PesterConfiguration]@{
                Run    = @{
                    ScriptBlock = { Describe 'a' { It 'b' { 1 | Should -Be 1 } } }
                    PassThru    = $true
                }
                Should = @{
                    DisableV5 = $false
                }
            }

            $r = Invoke-Pester -Configuration $c
            $r.Result | Verify-Equal "Passed"
        }
    }
}
