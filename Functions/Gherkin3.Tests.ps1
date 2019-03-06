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
            #Get-ChildItem $PWD -Recurse | Remove-Item -Forcel
            Get-ChildItem $PWD -Recurse | Remove-Item -Force -Recurse
            Set-Location $CWD
        }

        Context 'Selecting files to load' {
            It 'Requires Environment.ps1 files first' {
                $null = New-Item -ItemType File -Path './features/step_definitions/non_supportFile.ps1'
                $null = New-Item -ItemType File -Path './features/support' -Name 'A_File.ps1'

                $files = Get-SupportScript "$PWD/features"

                $files | Should -HaveCount 2
                $files[0].Name | Should -Be 'Environment.ps1'
                $files[1].Name | Should -Be 'A_File.ps1'
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

                $files = Get-SupportScript "$PWD/features"
                $files | Should -HaveCount 6
                $files[0].FullName | Should Match ([regex]::Escape((Join-Path (Join-Path 'features' 'support') 'Environment.ps1')))
                $files[1].FullName | Should Match ([regex]::Escape((Join-Path (Join-Path (Join-Path 'features' 'foo') 'support') 'Environment.ps1')))
                $files[2].FullName | Should Match ([regex]::Escape((Join-Path (Join-Path (Join-Path (Join-Path 'features' 'foo') 'bar') 'support') 'Environment.ps1')))
                $files[3].Fullname | Should Match ([regex]::Escape((Join-Path (Join-Path 'features' 'support') 'A_File.ps1')))
                $files[4].Fullname | Should Match ([regex]::Escape((Join-Path (Join-Path (Join-Path 'features' 'foo') 'support') 'A_File.ps1')))
                $files[5].FullName | Should Match ([regex]::Escape((Join-Path (Join-Path (Join-Path (Join-Path 'features' 'foo') 'bar') 'support') 'A_File.ps1')))
            }
        }

        Context '-Exclude' {
            It 'excludes a PowerShell file from requiring when the name matches exactly' {
                $null = New-Item -ItemType File -Path './features/support' -Name 'A_File.ps1'

                $files = Get-SupportScript "$PWD/features" -Exclude "A_File.ps1"

                $files | Should -HaveCount 1
                $files[0].FullName | Should Match ([regex]::Escape((Join-Path (Join-Path 'features' 'support') 'Environment.ps1')))
            }

            It 'excludes all PowerShell files that match the provided patterns from requiring' {
                $null = New-Item -ItemType File -Path './features/support' -Name 'foof.ps1'
                $null = New-Item -ItemType File -Path './features/support' -Name 'food.ps1'
                $null = New-Item -ItemType File -Path './features/support' -Name 'fooz.ps1'
                $null = New-Item -ItemType File -Path './features/support' -Name 'bar.ps1'
                $null = New-Item -ItemType File -Path './features/support' -Name 'blah.ps1'

                $files = Get-SupportScript "$PWD/features" -Exclude 'foo[df]', 'blah'
                $files | Should -HaveCount 3
                $files[0].FullName | Should Match ([regex]::Escape((Join-Path (Join-Path 'features' 'support') 'Environment.ps1')))
                $files[1].FullName | Should Match ([regex]::Escape((Join-Path (Join-Path 'features' 'support') 'bar.ps1')))
                $files[2].FullName | Should Match ([regex]::Escape((Join-Path (Join-Path 'features' 'support') 'fooz.ps1')))
            }
        }
    }

    Describe 'Get-FeatureFile' -Tag Gherkin2 {
        Context 'selecting feature files' {
            It 'preserves the order of the feature files' {

            }
        }
    }
}

Describe 'Invoke-Gherkin' -Tag Gherkin2 {
    Context 'A ./features directory is present with no feature files' {
        It 'Returns 0 scenarios and 0 steps executed in 0m0.000s' {
            In $TestDrive {
                Invoke-Gherkin3 -Init

                $Results = Invoke-Gherkin3 -PassThru

                $Results | Should -Not -BeNullOrEmpty
                $Results.TotalScenarios | Should -BeExactly 0
                $Results.TotalSteps | Should -BeExactly 0
                $Results.TestRunDuration | Should -Be ([TimeSpan]::Zero)
            }
        }
    }
}

InModuleScope 'Pester' {
    Describe 'Get-FeatureFile' -Tag Gherkin, Gherkin2 {
        # TODO: See GH #1251
        # BeforeAll {
        #     $CWD = Get-Location -PSProvider FileSystem
        #     try {
        #         Set-Location $TestDrive
        #         # Creates the conventional directory structure for Gherkin tests.
        #         Invoke-Gherkin3 -Init

        #         foreach ($i in 1..2) {
        #             $null = New-Item -ItemType File -Path (Join-Path $TestDrive 'features') -Name "Feature$i.feature"
        #         }
        #         $folder1 = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'features') -Name 'folder1'
        #         $null = New-Item -ItemType File -Path $folder1.FullName -Name 'Feature3.feature'

        #         # Create an uncoventional directory structure for Gherkin tests.
        #         $unconventional = New-Item -ItemType Directory -Path $TestDrive -Name 'unconventional'
        #         foreach ($i in 1..2) {
        #             $null = New-Item -ItemType File -Path $unconventional.Fullname -Name "Feature$i.feature"
        #         }
        #         $folder1 = New-Item -ItemType Directory -Path $unconventional.Fullname -Name 'folder1'
        #         $null = New-Item -ItemType File -Path $folder1.FullName -Name 'Feature3.feature'
        #     } finally {
        #         Set-Location $CWD
        #     }
        # }

        BeforeEach {
            $CWD = Get-Location -PSProvider FileSystem
            Set-Location $TestDrive
            if (!(Test-Path (Join-Path $TestDrive 'features'))) {
                # Creates the conventional directory structure for Gherkin tests.
                Invoke-Gherkin3 -Init

                foreach ($i in 1..2) {
                    $null = New-Item -ItemType File -Path (Join-Path $TestDrive 'features') -Name "Feature$i.feature"
                }
                $folder1 = New-Item -ItemType Directory -Path (Join-Path $TestDrive 'features') -Name 'folder1'
                $null = New-Item -ItemType File -Path $folder1.FullName -Name 'Feature3.feature'
            }

            if (!(Test-Path (Join-Path $TestDrive 'unconventional'))) {
                # Create an uncoventional directory structure for Gherkin tests.
                $unconventional = New-Item -ItemType Directory -Path $TestDrive -Name 'unconventional'
                foreach ($i in 1..2) {
                    $null = New-Item -ItemType File -Path $unconventional.Fullname -Name "Feature$i.feature"
                }
                $folder1 = New-Item -ItemType Directory -Path $unconventional.Fullname -Name 'folder1'
                $null = New-Item -ItemType File -Path $folder1.FullName -Name 'Feature3.feature'
            }
        }

        AfterEach { Set-Location $CWD }

        Context 'Feature files are retrieved from the default, conventional path ''./features''' {
            It 'Returns 3 feature files' {
                $FeatureFiles = Get-FeatureFile "$PWD/features"

                $FeatureFiles | Should -HaveCount 3
                $FeatureFileNames = $FeatureFiles | Split-Path -Leaf
                foreach ($i in 1..3) {
                    $FeatureFileNames | Should -Contain "Feature$i.feature"
                }
            }

            It 'Returns Feature1.feature' {
                $FeatureFiles = @(Get-FeatureFile -Path "$PWD/features/Feature1.feature")
                $FeatureFiles | Should -HaveCount 1
                $FeatureFiles | Split-Path -Leaf |
                    Should -Contain 'Feature1.feature'
            }

            Context 'Features can be excluded' {
                It 'Does not return Feature1.feature' {
                    $FeatureFiles = Get-FeatureFile "$PWD/features" -Exclude 'Feature1.feature'
                    $FeatureFiles | Should -HaveCount 2
                    $FeatureFiles | Split-Path -Leaf |
                        Should -Not -Contain 'Feature1.feature'
                }

                It 'Does not return Feature3.feature' {
                    $FeatureFiles = Get-FeaturefIle "$PWD/features" -Exclude 'Feature3.feature'
                    $FeatureFiles | Should -HaveCount 2
                    $FeatureFiles | Split-Path -Leaf |
                        Should -Not -Contain 'Feature3.feature'
                }

                It 'Does not return features in folder1' {
                    $FeatureFiles = Get-FeatureFile "$PWD/features" -Exclude 'folder1'
                    $FeatureFiles | Should -HaveCount 2
                    $FeatureFiles | Split-Path -Leaf |
                        Should -Not -Contain 'Feature3.feature'
                }

                It 'Only returns Feature2.feature' {
                    $FeatureFiles = @(Get-FeatureFile "$Pwd/features" -Exclude 'Feature1.feature','folder1')
                    $FeatureFiles | Should -HaveCount 1
                    $FeatureFiles | Split-Path -Leaf |
                        Should -Contain 'Feature2.feature'
                }

                It 'Does not return features matching Fea*3.feature' {
                    $FeatureFiles = Get-FeatureFile "$PWD/features" -Exclude 'Fea.*3\.feature'
                    $FeatureFiles | Should -HaveCount 2
                    $FeatureFiles | Split-Path -Leaf |
                        Should -Not -Contain 'Feature3.feature'
                }
            }
        }

        Context 'Find all features at and below a specified, unconventional folder' {
            It 'Returns 3 feature files' {
                $FeatureFiles = Get-FeatureFile $unconventional.FullName

                $FeatureFiles | Should -HaveCount 3
                $FeatureFileNames = $FeatureFiles | Split-Path -Leaf
                foreach ($i in 1..3) {
                    $FeatureFileNames | Should -Contain "Feature$i.feature"
                }
            }
        }

        Context 'Can accept a list of paths to feature files' {
            It 'Returns 6 feature files' {
                $ActualFeatureFiles = Get-FeatureFile -Path "$PWD/features", $unconventional.FullName
                $ActualFeatureFiles | Should -HaveCount 6
                $ExpectedFeatureFiles = foreach ($i in 1..3) {
                    if ($i -lt 3) {
                        'features', $unconventional.Name |
                            ForEach-Object { Join-Path $_ "Feature$i.feature" }
                    } else {
                        'features', $unconventional.Name |
                            ForEach-Object { Join-Path $_ 'folder1' } |
                            ForEach-Object { Join-Path $_ "Feature$i.feature" }
                    }
                }
                foreach ($expectedFeatureFile in $ExpectedFeatureFiles) {
                    $ActualFeatureFiles |
                        Where-Object { $_.FullName -match [Regex]::Escape($expectedFeatureFile) } |
                        Should -HaveCount 1
                }
            }

        }
    }
}
