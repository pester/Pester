if ($PSVersionTable.PSVersion.Major -le 2) { return }

InModuleScope Pester {
    Describe 'Code Coverage Analysis' {
        $root = (Get-PSDrive TestDrive).Root

        $null = New-Item -Path $root\TestScript.ps1 -ItemType File -ErrorAction SilentlyContinue

        Set-Content -Path $root\TestScript.ps1 -Value @'
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

        Context 'Entire file' {
            $testState = New-PesterState -Path $root

            # Path deliberately duplicated to make sure the code doesn't produce multiple breakpoints for the same commands
            Enter-CoverageAnalysis -CodeCoverage "$root\TestScript.ps1", "$root\TestScript.ps1" -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should Be 7
            }

            $null = & "$root\TestScript.ps1"
            $coverageReport = Get-CoverageReport -PesterState $testState

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should Be 6
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should Be 7
            }

            It 'Reports the proper number of analyzed files' {
                $coverageReport.NumberOfFilesAnalyzed | Should Be 1
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should Be 1
            }

            It 'Reports the correct missed command' {
                $coverageReport.MissedCommands[0].Command | Should Be "'I am function two.  I never get called.'"
            }

            Exit-CoverageAnalysis -PesterState $testState
        }

        Context 'Single function with missed commands' {
            $testState = New-PesterState -Path $root

            Enter-CoverageAnalysis -CodeCoverage @{Path = "$root\TestScript.ps1"; Function = 'FunctionTwo'} -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should Be 1
            }

            $null = & "$root\TestScript.ps1"
            $coverageReport = Get-CoverageReport -PesterState $testState

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should Be 0
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should Be 1
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should Be 1
            }

            It 'Reports the correct missed command' {
                $coverageReport.MissedCommands[0].Command | Should Be "'I am function two.  I never get called.'"
            }

            Exit-CoverageAnalysis -PesterState $testState
        }

        Context 'Single function with no missed commands' {
            $testState = New-PesterState -Path $root

            Enter-CoverageAnalysis -CodeCoverage @{Path = "$root\TestScript.ps1"; Function = 'FunctionOne'} -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should Be 5
            }

            $null = & "$root\TestScript.ps1"
            $coverageReport = Get-CoverageReport -PesterState $testState

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should Be 5
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should Be 5
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should Be 0
            }

            Exit-CoverageAnalysis -PesterState $testState
        }

        Context 'Range of lines' {
            $testState = New-PesterState -Path $root

            Enter-CoverageAnalysis -CodeCoverage @{Path = "$root\TestScript.ps1"; StartLine = 11; EndLine = 12 } -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should Be 2
            }

            $null = & "$root\TestScript.ps1"
            $coverageReport = Get-CoverageReport -PesterState $testState

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should Be 2
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should Be 2
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should Be 0
            }

            Exit-CoverageAnalysis -PesterState $testState
        }

        Context 'Wildcard resolution' {
            $testState = New-PesterState -Path $root

            Enter-CoverageAnalysis -CodeCoverage @{Path = "$root\*.ps1"; Function = '*' } -PesterState $testState

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should Be 6
            }

            $null = & "$root\TestScript.ps1"
            $coverageReport = Get-CoverageReport -PesterState $testState

            It 'Reports the proper number of executed commands' {
                $coverageReport.NumberOfCommandsExecuted | Should Be 5
            }

            It 'Reports the proper number of analyzed commands' {
                $coverageReport.NumberOfCommandsAnalyzed | Should Be 6
            }

            It 'Reports the proper number of analyzed files' {
                $coverageReport.NumberOfFilesAnalyzed | Should Be 1
            }

            It 'Reports the proper number of missed commands' {
                $coverageReport.MissedCommands.Count | Should Be 1
            }

            It 'Reports the correct missed command' {
                $coverageReport.MissedCommands[0].Command | Should Be "'I am function two.  I never get called.'"
            }

            Exit-CoverageAnalysis -PesterState $testState
        }
    }

    Describe 'Stripping common parent paths' {
        $paths = @(
            'C:\Common\Folder\UniqueSubfolder1\File.ps1'
            'C:\Common\Folder\UniqueSubfolder2\File2.ps1'
            'C:\Common\Folder\UniqueSubfolder3\File3.ps1'
        )

        $commonPath = Get-CommonParentPath -Path $paths

        It 'Identifies the correct parent path' {
            $commonPath | Should Be 'C:\Common\Folder'
        }

        It 'Strips the common path correctly' {
            Get-RelativePath -Path $paths[0] -RelativeTo $commonPath |
            Should Be 'UniqueSubfolder1\File.ps1'
        }
    }

    if ((Get-Module -ListAvailable PSDesiredStateConfiguration) -and $PSVersionTable.PSVersion.Major -ge 4)
    {
        Describe 'Analyzing coverage of a DSC configuration' {
            $root = (Get-PSDrive TestDrive).Root

            $null = New-Item -Path $root\TestScriptWithConfiguration.ps1 -ItemType File -ErrorAction SilentlyContinue

            Set-Content -Path $root\TestScriptWithConfiguration.ps1 -Value @'
                $line1 = $true   # Triggers breakpoint
                $line2 = $true   # Triggers breakpoint

                configuration MyTestConfig   # does NOT trigger breakpoint
                {
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

            It 'Has the proper number of breakpoints defined' {
                $testState.CommandCoverage.Count | Should Be 7
            }

            $null = . "$root\TestScriptWithConfiguration.ps1"

            $coverageReport = Get-CoverageReport -PesterState $testState
            It 'Reports the proper number of missed commands before running the configuration' {
                $coverageReport.MissedCommands.Count | Should Be 4
            }

            MyTestConfig -OutputPath $root

            $coverageReport = Get-CoverageReport -PesterState $testState
            It 'Reports the proper number of missed commands after running the configuration' {
                $coverageReport.MissedCommands.Count | Should Be 2
            }

            Exit-CoverageAnalysis -PesterState $testState
        }
    }
}
