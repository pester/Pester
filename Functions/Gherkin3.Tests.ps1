Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path

InModuleScope Pester {
    Describe 'New-GherkinProject' -Tag Gherkin2 {
        Context 'A Gherkin project does not exist at the current working directory' {
            BeforeAll { Mock New-Item -ModuleName Pester -MockWith { } }

            BeforeEach {
                $CWD = Get-Location -PSProvider FileSystem
                Set-Location $TestDrive
            }

            AfterEach { Set-Location $CWD }

            It 'Creates ''features'' directory' {
                $Results = New-GherkinProject

                Assert-MockCalled New-Item -ModuleName Pester -ParameterFilter {
                    $ItemType -eq 'Directory' -and $Path -eq $PWD -and $Name -eq 'features'
                } -Exactly 1

                $Results[0] | Should -Be '  create   features'
            }

            It 'Creates ''features/step_definitions'' directory' {
                $Results = New-GherkinProject

                Assert-MockCalled New-Item -ModuleName Pester -ParameterFilter {
                    $ItemType -eq 'Directory' -and $Path -eq (Join-Path $PWD 'features') -and $Name -eq 'step_definitions'
                } -Exactly 1

                $Results[1] | Should -Be "  create   $(Join-Path 'features' 'step_definitions')"
            }

            It 'Creates ''features/support'' directory' {
                $Results = New-GherkinProject

                Assert-MockCalled New-Item -ModuleName Pester -ParameterFilter {
                    $ItemType -eq 'Directory' -and $Path -eq (Join-Path $PWD 'features') -and $Name -eq 'support'
                } -Exactly 1

                $Results[2] | Should -Be "  create   $(Join-Path 'features' 'support')"
            }

            It 'Creates ''features/support/Environment.ps1'' file' {
                $Results = New-GherkinProject

                Assert-MockCalled New-Item -ModuleName Pester -ParameterFilter {
                    $ItemType -eq 'File' -and $Path -eq (Join-Path $PWD (Join-Path 'features' 'support')) -and $Name -eq 'Environment.ps1'
                } -Exactly 1

                $Results[3] | Should -Be "  create   $(Join-Path (Join-Path 'features' 'support') 'Environment.ps1')"
            }
        }

        Context 'A Gherkin project exists at the current working directory' {
            BeforeEach {
                $CWD = Get-Location -PSProvider FileSystem
                Set-Location $TestDrive
                $null = New-GherkinProject
            }

            AfterEach { Set-Location $CWD }

            It 'Does not create ''features'' directory' {
                $Results = New-GherkinProject

                Assert-MockCalled New-Item       -ModuleName Pester -ParameterFilter {
                    $ItemType -eq 'Directory' -and $Path -eq $PWD -and $Name -eq 'features'
                } -Exactly 0

                $Results[0] | Should -Be '   exist   features'
            }

            It 'Does not create ''features/step_definitions'' directory' {
                $Results = New-GherkinProject

                Assert-MockCalled New-Item -ModuleName Pester -ParameterFilter {
                    $ItemType -eq 'Directory' -and $Path -eq (Join-Path $PWD 'features') -and $Name -eq 'step_definitions'
                } -Exactly 0

                $Results[1] | Should -Be "   exist   $(Join-Path 'features' 'step_definitions')"
            }

            It 'Does not create ''features/support'' directory' {
                $Results = New-GherkinProject

                Assert-MockCalled New-Item -ModuleName Pester -ParameterFilter {
                    $ItemType -eq 'Directory' -and $Path -eq (Join-Path $PWD 'features') -and $Name -eq 'support'
                } -Exactly 0

                $Results[2] | Should -Be "   exist   $(Join-Path 'features' 'support')"
            }

            It 'Does not create ''features/support/Environment.ps1'' file' {
                $Results = New-GherkinProject

                Assert-MockCalled New-Item -ModuleName Pester -ParameterFilter {
                    $ItemType -eq 'File' -and $Path -eq (Join-Path $PWD (Join-Path 'features' 'support')) -and $Name -eq 'Environment.ps1'
                } -Exactly 0

                $Results[3] | Should -Be "   exist   $(Join-Path (Join-Path 'features' 'support') 'Environment.ps1')"
            }
        }
    }

    Describe 'Get-SupportScript' -Tag Gherkin2 {
        BeforeEach {
            $CWD = Get-Location -PSProvider FileSystem
            Set-Location $TestDrive
            $null = New-GherkinProject
        }

        AfterEach {
            Get-ChildItem $PWD -Recurse | Remove-Item -Force -Recurse
            Set-Location $CWD
        }

        Context 'Selecting files to load' {
            It 'Requires Environment.ps1 files first' {
                $null = New-Item -ItemType File -Path './features/step_definitions/non_supportFile.ps1'
                $null = New-Item -ItemType File -Path './features/support' -Name 'A_File.ps1'

                $scriptFiles = Get-ScriptFile (Join-Path $PWD 'features')
                $supportFiles = Get-SupportScript $scriptFiles

                $supportFiles | Should -HaveCount 2
                $supportFiles[0].Name | Should -Be 'Environment.ps1'
                $supportFiles[1].Name | Should -Be 'A_File.ps1'
            }

            It 'features/support/Environment.ps1 is loaded before any other features/**/support/Environment.ps1 file' {
                $null = New-Item -ItemType Directory -Path './features' -Name 'foo'
                $null = New-Item -ItemType Directory -Path './features/foo' -Name 'support'
                $null = New-Item -ItemType Directory -Path './features/foo' -Name 'bar'
                $null = New-Item -ItemType Directory -Path './features/foo/bar' -Name 'support'
                $null = New-Item -ItemType File -Path './features/support' -Name 'A_File.ps1'
                $null = New-Item -ItemType File -Path './features/foo/support/Environment.ps1'
                $null = New-Item -ItemType File -Path './features/foo/support/A_File.ps1'
                $null = New-Item -ItemType File -Path './features/foo/bar/support/Environment.ps1'
                $null = New-Item -ItemType File -Path './features/foo/bar/support/A_File.ps1'

                $scriptFiles = Get-ScriptFile (Join-Path $PWD 'features')
                $supportFiles = Get-SupportScript $scriptFiles

                $supportFiles | Should -HaveCount 6
                $supportFiles[0].FullName | Should Match ([regex]::Escape((Join-Path (Join-Path 'features' 'support') 'Environment.ps1')))
                $supportFiles[1].FullName | Should Match ([regex]::Escape((Join-Path (Join-Path (Join-Path 'features' 'foo') 'support') 'Environment.ps1')))
                $supportFiles[2].FullName | Should Match ([regex]::Escape((Join-Path (Join-Path (Join-Path (Join-Path 'features' 'foo') 'bar') 'support') 'Environment.ps1')))
                $supportFiles[3].Fullname | Should Match ([regex]::Escape((Join-Path (Join-Path 'features' 'support') 'A_File.ps1')))
                $supportFiles[4].Fullname | Should Match ([regex]::Escape((Join-Path (Join-Path (Join-Path 'features' 'foo') 'support') 'A_File.ps1')))
                $supportFiles[5].FullName | Should Match ([regex]::Escape((Join-Path (Join-Path (Join-Path (Join-Path 'features' 'foo') 'bar') 'support') 'A_File.ps1')))
            }
        }

        Context '-Exclude' {
            It 'excludes a PowerShell file from requiring when the name matches exactly' {
                $null = New-Item -ItemType File -Path './features/support' -Name 'A_File.ps1'

                $scriptFiles = Get-ScriptFile (Join-Path $PWD 'features') -Exclude 'A_File.ps1'
                $supportFiles = Get-SupportScript $scriptFiles

                $supportFiles | Should -HaveCount 1
                $supportFiles[0].FullName | Should Match ([regex]::Escape((Join-Path (Join-Path 'features' 'support') 'Environment.ps1')))
            }

            It 'excludes all PowerShell files that match the provided patterns from requiring' {
                $null = New-Item -ItemType File -Path './features/support' -Name 'foof.ps1'
                $null = New-Item -ItemType File -Path './features/support' -Name 'food.ps1'
                $null = New-Item -ItemType File -Path './features/support' -Name 'fooz.ps1'
                $null = New-Item -ItemType File -Path './features/support' -Name 'bar.ps1'
                $null = New-Item -ItemType File -Path './features/support' -Name 'blah.ps1'

                $scriptFiles = Get-ScriptFile (Join-Path $PWD 'features') -Exclude 'foo[df]', 'blah'
                $supportFiles = Get-SupportScript $scriptFiles

                $supportFiles | Should -HaveCount 3
                $supportFiles[0].FullName | Should Match ([regex]::Escape((Join-Path (Join-Path 'features' 'support') 'Environment.ps1')))
                $supportFiles[1].FullName | Should Match ([regex]::Escape((Join-Path (Join-Path 'features' 'support') 'bar.ps1')))
                $supportFiles[2].FullName | Should Match ([regex]::Escape((Join-Path (Join-Path 'features' 'support') 'fooz.ps1')))
            }
        }
    }

    Describe 'Get-PotentialFeatureFile' -Tag Gherkin2 {
        Context 'selecting feature files' {
            BeforeEach {
                $CWD = Get-Location -PSProvider FileSystem
                Set-Location $TestDrive
                $null = New-GherkinProject
            }

            AfterEach {
                Get-ChildItem $PWD -Recurse | Remove-Item -Force -Recurse
                Set-Location $CWD
            }

            It 'preserves the order of the feature files' {
                $PotentialFeatureFiles = Get-PotentialFeatureFile -Path 'b.feature','c.feature','a.feature'

                $PotentialFeatureFiles | Should -HaveCount 3
                foreach ($n in 0..2) {
                    $PotentialFeatureFiles[$n] | Should -Be $(switch ($n) {
                        0 { 'b.feature' }
                        1 { 'c.feature' }
                        2 { 'a.feature' }
                    })
                }
            }

            It 'searches for all features in the specified directory' {
                Mock Get-ChildItem -Module 'Pester' -ParameterFilter { $Path -eq 'feature_directory' } -MockWith {
                    [IO.FileInfo]::new((Join-Path (Join-Path "$PWD" 'feature_directory') 'cucumber.feature'))
                }

                $PotentialFeatureFiles = Get-PotentialFeatureFile -Path 'feature_directory'
                $PotentialFeatureFiles | Should -Match 'cucumber.feature'
            }

            It 'defaults to the features directory when no feature files or paths are provided' {
                Mock Get-ChildItem -Module 'Pester' -ParameterFilter { $Path -eq 'features' } -MockWith {
                    [IO.FileInfo]::new((Join-Path (Join-Path "$PWD" 'features') 'cucumber.feature'))
                }

                $PotentialFeatureFiles = Get-PotentialFeatureFile
                $PotentialFeatureFiles | Should -Match 'cucumber.feature'
            }

            It 'gets the feature files from the rerun file' {
                $RerunFileContent = @"
cucumber.feature:1:3
cucumber.feature:5
cucumber.feature:10
domain folder/different cuke.feature:134
domain folder/cuke.feature:1
domain folder/different cuke.feature:4:5
bar.feature
"@

                $RerunFile = New-Item -ItemType File -Path 'rerun.txt'
                Set-Content $RerunFile -Value $RerunFileContent

                $ActualPotentialFeatureFiles = Get-PotentialFeatureFile '@rerun.txt'
                $ExpectedPotentialFeatureFiles = $RerunFileContent -split [Environment]::NewLine

                foreach ($i in 0..($ExpectedPotentialFeatureFiles.Length - 1)) {
                    $ActualPotentialFeatureFiles[$i] | Should -Be $ExpectedPotentialFeatureFiles[$i]
                }
            }
        }
    }

    Describe 'ConvertTo-FileSpec' -Tag Gherkin2 {
        BeforeEach {
            $FileSpecs = 'features/foo.feature:1:2:3','features/bar.feature:4:5:6', 'features/baz.feature' | ConvertTo-FileSpec
            $Locations = $FileSpecs.Locations
            $Files = $FileSpecs | ForEach-Object { $_.File } | Sort-Object -Unique
        }

        It 'parses locations from files' {
            $Locations | Should -HaveCount 7
            foreach ($i in 1..($Locations.Length - 1)) {
                $Locations[$i-1].Line | Should -BeExactly $i
            }
        }

        It 'parses when no line number is specified' {
            $Last = ($Locations | Select-Object -Last 1)
            $Last.File | Should -BeExactly 'features/baz.feature'
            $Lst.Lines | Should -BeNullOrEmpty
        }
    }
}

Describe 'Invoke-Gherkin' -Tag Gherkin2 {
    Context 'A ./features directory is present with no feature files' {
        BeforeEach {
            $CWD = Get-Location -PSProvider FileSystem
            Set-Location $TestDrive
        }

        AfterEach {
            Get-ChildItem $PWD -Recurse | Remove-Item -Force -Recurse
            Set-Location $CWD
        }

        It 'Returns 0 scenarios and 0 steps executed in 0m0.000s' {
            Invoke-Gherkin3 -Init

            $Results = Invoke-Gherkin3 -PassThru

            $Results | Should -Not -BeNullOrEmpty
            $Results.TotalScenarios | Should -BeExactly 0
            $Results.TotalSteps | Should -BeExactly 0
            $Results.TestRunDuration | Should -Be ([TimeSpan]::Zero)
        }
    }
}
