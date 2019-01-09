Set-StrictMode -Version Latest

if ($PSVersionTable.PSVersion.Major -le 2) {
    return
}

InModuleScope Pester {
    function Clear-WhiteSpace ($Text) {
        # clear whitespace in formatted xml so we can keep the XML in the test file
        # formatted and easily see changes in source control
        "$($Text -replace "(`t|`n|`r)"," " -replace "\s+"," " -replace "\s*<","<" -replace ">\s*", ">")".Trim()
    }

    Describe 'Code Coverage Analysis' {
        $root = (Get-PSDrive TestDrive).Root

        $testScriptPath = Join-Path -Path $root -ChildPath TestScript.ps1
        $testScript2Path = Join-Path -Path $root -ChildPath TestScript2.ps1

        $null = New-Item -Path $testScriptPath -ItemType File -ErrorAction SilentlyContinue

        Set-Content -Path $testScriptPath -Value @'
            function FunctionOne
            {
                function NestedFunction
                {
                    'I am the nested function.'
                    'I get fully executed.'
                }

                if ($true)
                {
                    'I am functionOne'
                    NestedFunction
                }

                if ($false) { 'I cannot get called.' }

                Invoke-Command { 'I get called.' }
            }

            function FunctionTwo
            {
                'I am function two.  I never get called.'
            }

            FunctionOne

'@
        # Classes have been introduced in PowerShell 5.0
        if ($PSVersionTable.PSVersion.Major -ge 5) {
            Add-Content -Path $testScriptPath -Value @'

            class MyClass
            {
                MyClass()
                {
                    'I am the constructor.'
                }

                MethodOne()
                {
                    'I am method one.'
                }

                hidden static MethodTwo()
                {
                    'I am method two. I never get called.'
                }
            }

            $class = [MyClass]::new()
            $class.MethodOne()

'@
        }
        else {
            # Before that, let's just create equivalent commands to above class with exact same line numbers
            Add-Content -Path $testScriptPath -Value @'

            #class MyClass
            #{
                function MyClass
                {
                    'I am the constructor.'
                }

                function MethodOne
                {
                    'I am method one.'
                }

                function MethodTwo
                {
                    'I am method two. I never get called.'
                }
            #}

            MyClass
            MethodOne

'@
        }

        $null = New-Item -Path $testScript2Path -ItemType File -ErrorAction SilentlyContinue

        Set-Content -Path $testScript2Path -Value @'
            'Some {0} file' `
                -f `
                'other'

'@

        Context 'Entire file' {
            $testState = New-PesterState -Path $root

            # Path deliberately duplicated to make sure the code doesn't produce multiple breakpoints for the same commands
            Enter-CoverageAnalysis -CodeCoverage $testScriptPath, $testScriptPath, $testScript2Path -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should -Be 17
            }

            $null = & $testScriptPath
            $null = & $testScript2Path
            $coverageReport = Get-CoverageReport -PesterState $testState

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should -Be 14
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should -Be 17
            }

            It 'Reports the proper number of analyzed files' {
                $coverageReport.NumberOfFilesAnalyzed | Should -Be 2
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should -Be 3
            }

            It 'Reports the correct missed command' {
                $coverageReport.MissedCommands[0].Command | Should -Be "'I cannot get called.'"
                $coverageReport.MissedCommands[1].Command | Should -Be "'I am function two.  I never get called.'"
                $coverageReport.MissedCommands[2].Command | Should -Be "'I am method two. I never get called.'"
            }

            It 'Reports the proper number of hit commands' {
                $coverageReport.HitCommands.Count | Should -Be 14
            }

            It 'Reports the correct hit command' {
                $coverageReport.HitCommands[0].Command | Should -Be "'I am the nested function.'"
            }

            It 'Reports the correct class names' {
                $coverageReport.HitCommands[0].Class | Should -BeNullOrEmpty
                # Classes have been introduced in PowerShell 5.0
                if ($PSVersionTable.PSVersion.Major -ge 5) {
                    $coverageReport.HitCommands[9].Class | Should -Be 'MyClass'
                    $coverageReport.MissedCommands[2].Class | Should -Be 'MyClass'
                }
                else {
                    $coverageReport.HitCommands[9].Class | Should -BeNullOrEmpty
                    $coverageReport.MissedCommands[2].Class | Should -BeNullOrEmpty
                }
            }

            It 'Reports the correct function names' {
                $coverageReport.HitCommands[0].Function | Should -Be 'NestedFunction'
                $coverageReport.HitCommands[2].Function | Should -Be 'FunctionOne'
                $coverageReport.HitCommands[9].Function | Should -Be 'MyClass'
                $coverageReport.MissedCommands[2].Function | Should -Be 'MethodTwo'
            }

            It 'JaCoCo report must be correct' {
                [String]$jaCoCoReportXml = Get-JaCoCoReportXml -PesterState $testState -CoverageReport $coverageReport
                $jaCoCoReportXml = $jaCoCoReportXml -replace 'Pester \([^\)]*', 'Pester (date'
                $jaCoCoReportXml = $jaCoCoReportXml -replace 'start="[0-9]*"', 'start=""'
                $jaCoCoReportXml = $jaCoCoReportXml -replace 'dump="[0-9]*"', 'dump=""'
                $jaCoCoReportXml = $jaCoCoReportXml -replace "$([System.Environment]::NewLine)", ''
                $jaCoCoReportXml = $jaCoCoReportXml -replace "$(Split-Path -Path $root -Leaf)", 'CommonRoot'
                $jaCoCoReportXml = $jaCoCoReportXml.Replace($root.Replace('\', '/'), '')
                (Clear-WhiteSpace $jaCoCoReportXml) | Should -Be (Clear-WhiteSpace '
                <?xml version="1.0" encoding="UTF-8" standalone="no"?>
                <!DOCTYPE report PUBLIC "-//JACOCO//DTD Report 1.1//EN" "report.dtd">
                <report name="Pester (date)">
                    <sessioninfo id="this" start="" dump="" />
                    <package name="CommonRoot">
                        <class name="CommonRoot/TestScript" sourcefilename="TestScript.ps1">
                            <method name="NestedFunction" desc="()" line="5">
                                <counter type="INSTRUCTION" missed="0" covered="2" />
                                <counter type="LINE" missed="0" covered="2" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <method name="FunctionOne" desc="()" line="9">
                                <counter type="INSTRUCTION" missed="1" covered="6" />
                                <counter type="LINE" missed="0" covered="5" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <method name="FunctionTwo" desc="()" line="22">
                                <counter type="INSTRUCTION" missed="1" covered="0" />
                                <counter type="LINE" missed="1" covered="0" />
                                <counter type="METHOD" missed="1" covered="0" />
                            </method>
                            <method name="&lt;script&gt;" desc="()" line="25">
                                <counter type="INSTRUCTION" missed="0" covered="3" />
                                <counter type="LINE" missed="0" covered="3" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <method name="MyClass" desc="()" line="32">
                                <counter type="INSTRUCTION" missed="0" covered="1" />
                                <counter type="LINE" missed="0" covered="1" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <method name="MethodOne" desc="()" line="37">
                                <counter type="INSTRUCTION" missed="0" covered="1" />
                                <counter type="LINE" missed="0" covered="1" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <method name="MethodTwo" desc="()" line="42">
                                <counter type="INSTRUCTION" missed="1" covered="0" />
                                <counter type="LINE" missed="1" covered="0" />
                                <counter type="METHOD" missed="1" covered="0" />
                            </method>
                            <counter type="INSTRUCTION" missed="3" covered="13" />
                            <counter type="LINE" missed="2" covered="12" />
                            <counter type="METHOD" missed="2" covered="5" />
                            <counter type="CLASS" missed="0" covered="1" />
                        </class>
                        <class name="CommonRoot/TestScript2" sourcefilename="TestScript2.ps1">
                            <method name="&lt;script&gt;" desc="()" line="1">
                                <counter type="INSTRUCTION" missed="0" covered="1" />
                                <counter type="LINE" missed="0" covered="1" />
                                <counter type="METHOD" missed="0" covered="1" />
                            </method>
                            <counter type="INSTRUCTION" missed="0" covered="1" />
                            <counter type="LINE" missed="0" covered="1" />
                            <counter type="METHOD" missed="0" covered="1" />
                            <counter type="CLASS" missed="0" covered="1" />
                        </class>
                        <sourcefile name="TestScript.ps1">
                            <line nr="5" mi="0" ci="1" />
                            <line nr="6" mi="0" ci="1" />
                            <line nr="9" mi="0" ci="1" />
                            <line nr="11" mi="0" ci="1" />
                            <line nr="12" mi="0" ci="1" />
                            <line nr="15" mi="1" ci="1" />
                            <line nr="17" mi="0" ci="2" />
                            <line nr="22" mi="1" ci="0" />
                            <line nr="25" mi="0" ci="1" />
                            <line nr="32" mi="0" ci="1" />
                            <line nr="37" mi="0" ci="1" />
                            <line nr="42" mi="1" ci="0" />
                            <line nr="46" mi="0" ci="1" />
                            <line nr="47" mi="0" ci="1" />
                            <counter type="INSTRUCTION" missed="3" covered="13" />
                            <counter type="LINE" missed="2" covered="12" />
                            <counter type="METHOD" missed="2" covered="5" />
                            <counter type="CLASS" missed="0" covered="1" />
                        </sourcefile>
                        <sourcefile name="TestScript2.ps1">
                            <line nr="1" mi="0" ci="1" />
                            <counter type="INSTRUCTION" missed="0" covered="1" />
                            <counter type="LINE" missed="0" covered="1" />
                            <counter type="METHOD" missed="0" covered="1" />
                            <counter type="CLASS" missed="0" covered="1" />
                        </sourcefile>
                        <counter type="INSTRUCTION" missed="3" covered="14" />
                        <counter type="LINE" missed="2" covered="13" />
                        <counter type="METHOD" missed="2" covered="6" />
                        <counter type="CLASS" missed="0" covered="2" />
                    </package>
                    <counter type="INSTRUCTION" missed="3" covered="14" />
                    <counter type="LINE" missed="2" covered="13" />
                    <counter type="METHOD" missed="2" covered="6" />
                    <counter type="CLASS" missed="0" covered="2" />
                </report>
                ')
            }

            It 'Reports the right line numbers' {
                $coverageReport.HitCommands[$coverageReport.NumberOfCommandsExecuted - 1].Line | Should -Be 1
                $coverageReport.HitCommands[$coverageReport.NumberOfCommandsExecuted - 1].StartLine | Should -Be 1
                $coverageReport.HitCommands[$coverageReport.NumberOfCommandsExecuted - 1].EndLine | Should -Be 3
            }

            It 'Reports the right column numbers' {
                $coverageReport.HitCommands[$coverageReport.NumberOfCommandsExecuted - 1].StartColumn | Should -Be 13
                $coverageReport.HitCommands[$coverageReport.NumberOfCommandsExecuted - 1].EndColumn | Should -Be 24
            }

            Exit-CoverageAnalysis -PesterState $testState
        }

        Context 'Single function with missed commands' {
            $testState = New-PesterState -Path $root

            Enter-CoverageAnalysis -CodeCoverage @{Path = $testScriptPath; Function = 'FunctionTwo'} -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should -Be 1
            }

            $null = & $testScriptPath
            $coverageReport = Get-CoverageReport -PesterState $testState

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should -Be 0
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should -Be 1
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should -Be 1
            }

            It 'Reports the correct missed command' {
                $coverageReport.MissedCommands[0].Command | Should -Be "'I am function two.  I never get called.'"
            }

            It 'Reports the proper number of hit commands' {
                $coverageReport.HitCommands.Count | Should -Be 0
            }

            Exit-CoverageAnalysis -PesterState $testState
        }

        Context 'Single function with no missed commands' {
            $testState = New-PesterState -Path $root

            Enter-CoverageAnalysis -CodeCoverage @{Path = $testScriptPath; Function = 'FunctionOne'} -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should -Be 9
            }

            $null = & $testScriptPath
            $coverageReport = Get-CoverageReport -PesterState $testState

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should -Be 8
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should -Be 9
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should -Be 1
            }

            It 'Reports the proper number of hit commands' {
                $coverageReport.HitCommands.Count | Should -Be 8
            }

            It 'Reports the correct hit command' {
                $coverageReport.HitCommands[0].Command | Should -Be "'I am the nested function.'"
            }

            Exit-CoverageAnalysis -PesterState $testState
        }

        Context 'Range of lines' {
            $testState = New-PesterState -Path $root

            Enter-CoverageAnalysis -CodeCoverage @{Path = $testScriptPath; StartLine = 11; EndLine = 12 } -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should -Be 2
            }

            $null = & $testScriptPath
            $coverageReport = Get-CoverageReport -PesterState $testState

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should -Be 2
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should -Be 2
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should -Be 0
            }

            It 'Reports the proper number of hit commands' {
                $coverageReport.HitCommands.Count | Should -Be 2
            }

            It 'Reports the correct hit command' {
                $coverageReport.HitCommands[0].Command | Should -Be "'I am functionOne'"
            }

            Exit-CoverageAnalysis -PesterState $testState
        }

        Context 'Function wildcard resolution' {
            $testState = New-PesterState -Path $root

            Enter-CoverageAnalysis -CodeCoverage @{Path = "$(Join-Path -Path $root -ChildPath *.ps1)"; Function = '*' } -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should -Be 13
            }

            $null = & $testScriptPath
            $coverageReport = Get-CoverageReport -PesterState $testState

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should -Be 10
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should -Be 13
            }

            It 'Reports the proper number of analyzed files' {
                $coverageReport.NumberOfFilesAnalyzed | Should -Be 1
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should -Be 3
            }

            It 'Reports the correct missed command' {
                $coverageReport.MissedCommands[0].Command | Should -Be "'I cannot get called.'"
                $coverageReport.MissedCommands[1].Command | Should -Be "'I am function two.  I never get called.'"
            }

            It 'Reports the proper number of hit commands' {
                $coverageReport.HitCommands.Count | Should -Be 10
            }

            It 'Reports the correct hit command' {
                $coverageReport.HitCommands[0].Command | Should -Be "'I am the nested function.'"
            }

            Exit-CoverageAnalysis -PesterState $testState
        }

        # Classes have been introduced in PowerShell 5.0
        if ($PSVersionTable.PSVersion.Major -ge 5) {
            Context 'Single class' {
                $testState = New-PesterState -Path $root

                Enter-CoverageAnalysis -CodeCoverage @{Path = $testScriptPath; Class = 'MyClass'} -PesterState $testState

                It 'Has the proper number of breakpoints defined' {
                    $testState.CommandCoverage.Count | Should -Be 3
                }

                $null = & $testScriptPath
                $coverageReport = Get-CoverageReport -PesterState $testState

                It 'Reports the proper number of executed commands' {
                    $coverageReport.NumberOfCommandsExecuted | Should -Be 2
                }

                It 'Reports the proper number of analyzed commands' {
                    $coverageReport.NumberOfCommandsAnalyzed | Should -Be 3
                }

                It 'Reports the proper number of missed commands' {
                    $coverageReport.MissedCommands.Count | Should -Be 1
                }

                It 'Reports the proper number of hit commands' {
                    $coverageReport.HitCommands.Count | Should -Be 2
                }

                Exit-CoverageAnalysis -PesterState $testState
            }

            Context 'Class wildcard resolution' {
                $testState = New-PesterState -Path $root

                Enter-CoverageAnalysis -CodeCoverage @{Path = $testScriptPath; Class = '*'} -PesterState $testState

                It 'Has the proper number of breakpoints defined' {
                    $testState.CommandCoverage.Count | Should -Be 3
                }

                $null = & $testScriptPath
                $coverageReport = Get-CoverageReport -PesterState $testState

                It 'Reports the proper number of executed commands' {
                    $coverageReport.NumberOfCommandsExecuted | Should -Be 2
                }

                It 'Reports the proper number of analyzed commands' {
                    $coverageReport.NumberOfCommandsAnalyzed | Should -Be 3
                }

                It 'Reports the proper number of missed commands' {
                    $coverageReport.MissedCommands.Count | Should -Be 1
                }

                It 'Reports the proper number of hit commands' {
                    $coverageReport.HitCommands.Count | Should -Be 2
                }

                Exit-CoverageAnalysis -PesterState $testState
            }

            Context 'Class and function filter' {
                $testState = New-PesterState -Path $root

                Enter-CoverageAnalysis -CodeCoverage @{Path = $testScriptPath; Class = 'MyClass'; Function = 'MethodTwo'} -PesterState $testState

                It 'Has the proper number of breakpoints defined' {
                    $testState.CommandCoverage.Count | Should -Be 1
                }

                $null = & $testScriptPath
                $coverageReport = Get-CoverageReport -PesterState $testState

                It 'Reports the proper number of executed commands' {
                    $coverageReport.NumberOfCommandsExecuted | Should -Be 0
                }

                It 'Reports the proper number of analyzed commands' {
                    $coverageReport.NumberOfCommandsAnalyzed | Should -Be 1
                }

                It 'Reports the proper number of missed commands' {
                    $coverageReport.MissedCommands.Count | Should -Be 1
                }

                It 'Reports the proper number of hit commands' {
                    $coverageReport.HitCommands.Count | Should -Be 0
                }

                Exit-CoverageAnalysis -PesterState $testState
            }
        }
        else {
            Context 'Single class when not supported' {
                $testState = New-PesterState -Path $root

                Enter-CoverageAnalysis -CodeCoverage @{Path = $testScriptPath; Class = 'MyClass'} -PesterState $testState

                It 'Has the proper number of breakpoints defined' {
                    $testState.CommandCoverage.Count | Should -Be 0
                }

                $null = & $testScriptPath
                $coverageReport = Get-CoverageReport -PesterState $testState

                It 'Reports the proper number of executed commands' {
                    $coverageReport.NumberOfCommandsExecuted | Should -Be 0
                }

                It 'Reports the proper number of analyzed commands' {
                    $coverageReport.NumberOfCommandsAnalyzed | Should -Be 0
                }

                It 'Reports the proper number of missed commands' {
                    $coverageReport.MissedCommands.Count | Should -Be 0
                }

                It 'Reports the proper number of hit commands' {
                    $coverageReport.HitCommands.Count | Should -Be 0
                }

                Exit-CoverageAnalysis -PesterState $testState
            }
        }
    }

    Describe 'Path resolution for test files' {
        $root = (Get-PSDrive TestDrive).Root

        $null = New-Item -Path $(Join-Path -Path $root -ChildPath TestScript.ps1) -ItemType File -ErrorAction SilentlyContinue

        $null = New-Item -Path $(Join-Path -Path $root -ChildPath TestScript.tests.ps1) -ItemType File -ErrorAction SilentlyContinue

        $null = New-Item -Path $(Join-Path -Path $root -ChildPath TestScript2.tests.ps1) -ItemType File -ErrorAction SilentlyContinue

        Context 'Using Path-input (auto-detect)' {
            It 'Excludes test files by default when using wildcard path' {
                $coverageInfo = Get-CoverageInfoFromUserInput "$(Join-Path -Path $root -ChildPath *)"

                $PesterTests = @($coverageInfo |
                        Select-Object -ExpandProperty Path |
                        Where-Object { $_ -match '\.tests.ps1$' })

                $PesterTests | Should -BeNullOrEmpty
            }

            It 'Includes test files when specified in wildcard path' {
                $coverageInfo = Get-CoverageInfoFromUserInput "$(Join-Path -Path $root -ChildPath *.tests.ps1)"

                $PesterTests = @($coverageInfo |
                        Select-Object -ExpandProperty Path |
                        Where-Object { $_ -match '\.tests.ps1$' })

                $PesterTests.Count | Should -Be 2
                $PesterTests | Should -Contain $(Join-Path -Path $root -ChildPath TestScript.tests.ps1)
                $PesterTests | Should -Contain $(Join-Path -Path $root -ChildPath TestScript2.tests.ps1)
            }

            It 'Includes test file when targeted directly using filepath' {
                $path = Join-Path -Path $root -ChildPath TestScript.tests.ps1

                $coverageInfo = Get-CoverageInfoFromUserInput $path

                $PesterTests = $coverageInfo | Select-Object -ExpandProperty Path

                $PesterTests | Should -Be $path
            }

        }

        Context 'Using object-input' {
            It 'Excludes test files when IncludeTests is not specified' {
                $coverageInfo = Get-CoverageInfoFromUserInput @{ Path = "$(Join-Path -Path $root -ChildPath TestScript.tests.ps1)" }

                $PesterTests = $coverageInfo | Select-Object -ExpandProperty Path

                $PesterTests | Should -BeNullOrEmpty
            }

            It 'Excludes test files when IncludeTests is false' {
                $coverageInfo = Get-CoverageInfoFromUserInput @{ Path = "$(Join-Path -Path $root -ChildPath TestScript.tests.ps1)"; IncludeTests = $false }

                $PesterTests = $coverageInfo | Select-Object -ExpandProperty Path

                $PesterTests | Should -BeNullOrEmpty
            }

            It 'Includes test files when IncludeTests is true' {
                $path = Join-Path -Path $root -ChildPath TestScript.tests.ps1

                $coverageInfo = Get-CoverageInfoFromUserInput @{ Path = $path; IncludeTests = $true }

                $PesterTests = $coverageInfo | Select-Object -ExpandProperty Path

                $PesterTests | Should -Be $path
            }
        }
    }

    Describe 'Stripping common parent paths' {

        If ( (& $SafeCommands['Get-Variable'] -Name IsLinux -Scope Global -ErrorAction SilentlyContinue) -or
            (& $SafeCommands['Get-Variable'] -Name IsMacOS -Scope Global -ErrorAction SilentlyContinue)) {

            $paths = @(
                Normalize-Path '/usr/lib/Common\Folder\UniqueSubfolder1/File.ps1'
                Normalize-Path '/usr/lib/Common\Folder\UniqueSubfolder2/File2.ps1'
                Normalize-Path '/usr/lib/Common\Folder\UniqueSubfolder3/File3.ps1'

                $expectedCommonPath = Normalize-Path '/usr/lib/Common/Folder'

            )

        }
        Else {

            $paths = @(
                Normalize-Path 'C:\Common\Folder\UniqueSubfolder1/File.ps1'
                Normalize-Path 'C:\Common\Folder\UniqueSubfolder2/File2.ps1'
                Normalize-Path 'C:\Common\Folder\UniqueSubfolder3/File3.ps1'

                $expectedCommonPath = Normalize-Path 'C:\Common/Folder'

            )

        }

        $commonPath = Get-CommonParentPath -Path $paths


        It 'Identifies the correct parent path' {
            $commonPath | Should -Be $expectedCommonPath
        }

        $expectedRelativePath = Normalize-Path 'UniqueSubfolder1/File.ps1'
        $relativePath = Get-RelativePath -Path $paths[0] -RelativeTo $commonPath

        It 'Strips the common path correctly' {
            $relativePath | Should -Be $expectedRelativePath
        }
    }

    #Workaround for Linux and MacOS - they don't have DSC by default installed with PowerShell - disable tests on these platforms
    if ((Get-Module -ListAvailable PSDesiredStateConfiguration) -and $PSVersionTable.PSVersion.Major -ge 4 -and ((GetPesterOS) -eq 'Windows')) {

        Describe 'Analyzing coverage of a DSC configuration' {
            $root = (Get-PSDrive TestDrive).Root

            $null = New-Item -Path $root\TestScriptWithConfiguration.ps1 -ItemType File -ErrorAction SilentlyContinue

            Set-Content -Path $root\TestScriptWithConfiguration.ps1 -Value @'
                $line1 = $true   # Triggers breakpoint
                $line2 = $true   # Triggers breakpoint

                configuration MyTestConfig   # does NOT trigger breakpoint
                {
                    Import-DscResource -ModuleName PSDesiredStateConfiguration # Triggers breakpoint in PowerShell v5 but not in v4

                    Node localhost    # Triggers breakpoint
                    {
                        WindowsFeature XPSViewer   # Triggers breakpoint
                        {
                            Name = 'XPS-Viewer'  # does NOT trigger breakpoint
                            Ensure = 'Present'   # does NOT trigger breakpoint
                        }
                    }

                    return # does NOT trigger breakpoint

                    $doesNotExecute = $true   # Triggers breakpoint
                }

                $line3 = $true   # Triggers breakpoint

                return   # does NOT trigger breakpoint

                $doesnotexecute = $true   # Triggers breakpoint
'@
            $testState = New-PesterState -Path $root

            Enter-CoverageAnalysis -CodeCoverage "$root\TestScriptWithConfiguration.ps1" -PesterState $testState

            #the AST does not parse Import-DscResource -ModuleName PSDesiredStateConfiguration on PowerShell 4
            $runsInPowerShell4 = $PSVersionTable.PSVersion.Major -eq 4
            It 'Has the proper number of breakpoints defined' {
                if ($runsInPowerShell4) {
                    $expected = 7
                }
                else {
                    $expected = 8
                }

                $testState.CommandCoverage.Count | Should -Be $expected
            }

            $null = . "$root\TestScriptWithConfiguration.ps1"

            $coverageReport = Get-CoverageReport -PesterState $testState
            It 'Reports the proper number of missed commands before running the configuration' {
                if ($runsInPowerShell4) {
                    $expected = 4
                }
                else {
                    $expected = 5
                }

                $coverageReport.MissedCommands.Count | Should -Be $expected
            }

            MyTestConfig -OutputPath $root

            $coverageReport = Get-CoverageReport -PesterState $testState
            It 'Reports the proper number of missed commands after running the configuration' {
                if ($runsInPowerShell4) {
                    $expected = 2
                }
                else {
                    $expected = 3
                }

                $coverageReport.MissedCommands.Count | Should -Be $expected
            }

            Exit-CoverageAnalysis -PesterState $testState
        }
    }
}
