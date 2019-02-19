Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe 'Invoke-Gherkin' -Tag Gherkin2 {
    Context 'No ./features directory is present' {
        It 'Displays helpful output to get you started' {
            Invoke-Gherkin3 | Should -Be 'No such file or directory - features. You can use `Invoke-Gherkin -Init` to get started.'
        }

        It 'Using ''-Init'' sets up an initial test structure' {
            Mock New-Item -MockWith { }

            Invoke-Gherkin3 -Init

            Assert-MockCalled New-Item -ParameterFilter {
                $ItemType -eq 'Directory' -and $Path -eq $PWD -and $Name -eq 'features'
            } -Exactly 1

            Assert-MockCalled New-Item -ParameterFilter {
                $ItemType -eq 'Directory' -and $Path -eq "$PWD/features"  -and $Name -eq 'step_definitions'
            } -Exactly 1

            Assert-MockCalled New-Item -ParameterFilter {
                $ItemType -eq 'Directory' -and $Path -eq "$PWD/features" -and $Name -eq 'support'
            } -Exactly 1

            Assert-MockCalled New-Item -ParameterFilter {
                $ItemType -eq 'File' -and $Path -eq "$PWD/features/support" -and $Name -eq 'env.ps1'
            } -Exactly 1
        }
    }

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
                    $FeatureFiles = Get-FeatureFile "$PWD/features" -Exclude 'Fea*3.feature'
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
