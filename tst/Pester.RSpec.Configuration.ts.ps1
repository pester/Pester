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

    $e = ($expected -replace "\\", '/').Trim('/')
    $a = ($actual -replace "\\", '/').Trim('/')

    if ($e -ne $a) {
        throw "Expected path '$e' to be equal to '$a'."
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

        t "StringArrayOption can be assigned PSCustomObjects in object array" {
            $path = (Join-Path (Split-Path $PWD) (Split-Path $PWD -Leaf)), (Join-Path (Split-Path $PWD) (Split-Path $PWD -Leaf)) | Resolve-Path
            $config = [PesterConfiguration]@{ Run = @{ Path = $path } }

            Verify-Equal $path[0].ToString() -Actual $config.Run.Path.Value[0]
            Verify-Equal $path[1].ToString() -Actual $config.Run.Path.Value[1]
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
        }

        t "Merges configuration when a PesterConfiguration object has been serialized" {
            if ($PSVersionTable.PSVersion.Major -lt 5) {
                return
            }

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
        }

        t "Merges configuration when a PesterConfiguration object has been serialized with a ScriptBlock" {
            if ($PSVersionTable.PSVersion.Major -lt 5) {
                return
            }

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

        t "Merges configuration when a PesterConfiguration object includes an array of values" {
            if ($PSVersionTable.PSVersion.Major -lt 5) {
                return
            }

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
                    PassThru    = $true
                }
                Debug  = @{
                    ShowFullErrors = $false
                }
                Output = @{
                    StackTraceVerbosity = "Something"
                }
            }

            $r = Invoke-Pester -Configuration $c
            $r.Containers[0].Blocks[0].ErrorRecord[0] | Verify-Equal "Unsupported level of stacktrace output 'Something'"
        }
    }
}
