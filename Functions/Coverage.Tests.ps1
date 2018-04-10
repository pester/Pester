Set-StrictMode -Version Latest

if ($PSVersionTable.PSVersion.Major -le 2) { return }

InModuleScope Pester {
    Describe 'Code Coverage Analysis' {
        $root = (Get-PSDrive TestDrive).Root

        $null = New-Item -Path $(Join-Path -Path $root -ChildPath TestScript.ps1) -ItemType File -ErrorAction SilentlyContinue

        Set-Content -Path $(Join-Path -Path $root -ChildPath TestScript.ps1) -Value @'
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
            }

            function FunctionTwo
            {
                'I am function two.  I never get called.'
            }

            FunctionOne

'@

        $null = New-Item -Path $(Join-Path -Path $root -ChildPath TestScript2.ps1) -ItemType File -ErrorAction SilentlyContinue

        Set-Content -Path $(Join-Path -Path $root -ChildPath TestScript2.ps1) -Value @'
            'Some other file'

'@

        Context 'Entire file' {
            $testState = New-PesterState -Path $root

            # Path deliberately duplicated to make sure the code doesn't produce multiple breakpoints for the same commands
            Enter-CoverageAnalysis -CodeCoverage "$(Join-Path -Path $root -ChildPath TestScript.ps1)", "$(Join-Path -Path $root -ChildPath TestScript.ps1)", "$(Join-Path -Path $root -ChildPath TestScript2.ps1)" -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should -Be 8
            }

            $null = & "$(Join-Path -Path $root -ChildPath TestScript.ps1)"
            $null = & "$(Join-Path -Path $root -ChildPath TestScript2.ps1)"
            $coverageReport = Get-CoverageReport -PesterState $testState

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should -Be 7
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should -Be 8
            }

            It 'Reports the proper number of analyzed files' {
                $coverageReport.NumberOfFilesAnalyzed | Should -Be 2
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should -Be 1
            }

            It 'Reports the correct missed command' {
                $coverageReport.MissedCommands[0].Command | Should -Be "'I am function two.  I never get called.'"
            }

            It 'Reports the proper number of hit commands' {
                $coverageReport.HitCommands.Count | Should -Be 7
            }

            It 'Reports the correct hit command' {
                $coverageReport.HitCommands[0].Command | Should -Be "'I am the nested function.'"
            }

            It 'JaCoCo report must be correct'{
                [String]$jaCoCoReportXml = Get-JaCoCoReportXml -PesterState $testState -CoverageReport $coverageReport
                $jaCoCoReportXml = $jaCoCoReportXml -replace 'Pester \([^\)]*','Pester (date'
                $jaCoCoReportXml = $jaCoCoReportXml -replace 'start="[0-9]*"','start=""'
                $jaCoCoReportXml = $jaCoCoReportXml -replace 'dump="[0-9]*"','dump=""'
                $jaCoCoReportXml = $jaCoCoReportXml -replace "$([System.Environment]::NewLine)",''
                $jaCoCoReportXml | should -be '<?xml version="1.0" encoding="UTF-8" standalone="no"?><!DOCTYPE report PUBLIC "-//JACOCO//DTD Report 1.0//EN" "report.dtd"><report name="Pester (date)"><sessioninfo id="this" start="" dump="" /><counter type="INSTRUCTION" missed="1" covered="7" /><counter type="LINE" missed="1" covered="7" /><counter type="METHOD" missed="1" covered="4" /><counter type="CLASS" missed="0" covered="2" /></report>'
            }
            Exit-CoverageAnalysis -PesterState $testState
        }

        Context 'Single function with missed commands' {
            $testState = New-PesterState -Path $root

            Enter-CoverageAnalysis -CodeCoverage @{Path = "$(Join-Path -Path $root -ChildPath TestScript.ps1)"; Function = 'FunctionTwo'} -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should -Be 1
            }

            $null = & "$(Join-Path -Path $root -ChildPath TestScript.ps1)"
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

            Enter-CoverageAnalysis -CodeCoverage @{Path = "$(Join-Path -Path $root -ChildPath TestScript.ps1)"; Function = 'FunctionOne'} -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should -Be 5
            }

            $null = & "$(Join-Path -Path $root -ChildPath TestScript.ps1)"
            $coverageReport = Get-CoverageReport -PesterState $testState

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should -Be 5
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should -Be 5
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should -Be 0
            }

            It 'Reports the proper number of hit commands' {
                $coverageReport.HitCommands.Count | Should -Be 5
            }

            It 'Reports the correct hit command' {
                $coverageReport.HitCommands[0].Command | Should -Be "'I am the nested function.'"
            }

            Exit-CoverageAnalysis -PesterState $testState
        }

        Context 'Range of lines' {
            $testState = New-PesterState -Path $root

            Enter-CoverageAnalysis -CodeCoverage @{Path = "$(Join-Path -Path $root -ChildPath TestScript.ps1)"; StartLine = 11; EndLine = 12 } -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should -Be 2
            }

            $null = & "$(Join-Path -Path $root -ChildPath TestScript.ps1)"
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

        Context 'Wildcard resolution' {
            $testState = New-PesterState -Path $root

            Enter-CoverageAnalysis -CodeCoverage @{Path = "$(Join-Path -Path $root -ChildPath *.ps1)"; Function = '*' } -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should -Be 6
            }

            $null = & "$(Join-Path -Path $root -ChildPath TestScript.ps1)"
            $coverageReport = Get-CoverageReport -PesterState $testState

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should -Be 5
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should -Be 6
            }

            It 'Reports the proper number of analyzed files' {
                $coverageReport.NumberOfFilesAnalyzed | Should -Be 1
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should -Be 1
            }

            It 'Reports the correct missed command' {
                $coverageReport.MissedCommands[0].Command | Should -Be "'I am function two.  I never get called.'"
            }

            It 'Reports the proper number of hit commands' {
                $coverageReport.HitCommands.Count | Should -Be 5
            }

            It 'Reports the correct hit command' {
                $coverageReport.HitCommands[0].Command | Should -Be "'I am the nested function.'"
            }

            Exit-CoverageAnalysis -PesterState $testState
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
                if($runsInPowerShell4) { $expected = 7 } else { $expected = 8 }

                $testState.CommandCoverage.Count | Should -Be $expected
            }

            $null = . "$root\TestScriptWithConfiguration.ps1"

            $coverageReport = Get-CoverageReport -PesterState $testState
            It 'Reports the proper number of missed commands before running the configuration' {
                if($runsInPowerShell4) { $expected = 4 } else { $expected = 5 }

                $coverageReport.MissedCommands.Count | Should -Be $expected
            }

            MyTestConfig -OutputPath $root

            $coverageReport = Get-CoverageReport -PesterState $testState
            It 'Reports the proper number of missed commands after running the configuration' {
                if($runsInPowerShell4) { $expected = 2 } else { $expected = 3 }

                $coverageReport.MissedCommands.Count | Should -Be $expected
            }

            Exit-CoverageAnalysis -PesterState $testState
        }
    }
}
