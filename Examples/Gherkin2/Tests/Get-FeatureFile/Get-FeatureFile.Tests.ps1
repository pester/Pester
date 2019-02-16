Set-StrictMode -Version Latest

InModuleScope 'Pester' {
    Describe 'Get-FeatureFile returns all specified feature files' -Tag Gherkin, Gherkin2 {
        BeforeAll {
            $CWD = Get-Location -PSProvider FileSystem
        }

        BeforeEach {
            Set-Location ".\Examples\Gherkin2\Tests\Get-FeatureFile"
            $PesterState = @{ SessionState = $PSCmdlet.SessionState }
        }

        AfterEach {
            Set-Location $CWD
        }

        Context 'Given feature files are to be retrieved from the default, conventional path ''./features''' {
            It 'Returns 3 feature files' {
                $FeatureFiles = Get-FeatureFile
                $FeatureFiles | Should -HaveCount 3
                $FeatureFileNames = $FeatureFiles | Select-Object -ExpandProperty Name
                'Feature1.feature', 'Feature2.feature', 'Feature3.feature' |
                    ForEach-Object { $FeatureFileNames | Should -Contain $_ }
            }
        }

        Context 'Given various exclusions' {
            It 'Does not return Feature1.feature' {
                $FeatureFiles = Get-FeatureFile -Exclude Feature1.feature
                $FeatureFiles | Should -HaveCount 2
                $FeatureFiles |
                    Select-Object -ExpandProperty Name |
                    Should -Not -Contain 'Feature1.feature'
            }

            It 'Does not return Feature3.feature' {
                $FeatureFiles = Get-FeatureFile -Exclude Feature3.feature
                $FeatureFiles | Should -HaveCount 2
                $FeatureFiles |
                    Select-Object -ExpandProperty Name |
                    Should -Not -Contain 'Feature3.feature'
            }

            It 'Only returns Feature2.feature' {
                $FeatureFiles = Get-FeatureFile -Exclude Feature1.feature,folder1
                $FeatureFiles | Should -HaveCount 1
                $FeatureFiles |
                    Select-Object -ExpandProperty Name |
                    ForEach-Object {
                        'Feature1.feature','Feature3.feature' | Should -Not -Contain $_
                    }
            }

            It 'Returns files not matching Fea*3.feature' {
                $FeatureFiles = Get-FeatureFile -Exclude 'Feat*3.feature'
                $FeatureFiles |
                    Select-Object -ExpandProperty Name |
                    Should -Not -Contain 'Feature3.feature'
            }
        }

        Context 'Given ''folder1'' is excluded' {
            It 'Does not return Feature3.feature' {
                $FeatureFiles = Get-FeatureFile -Exclude folder1
                $FeatureFiles | Should -HaveCount 2
                $FeatureFileNames = $FeatureFiles | Select-Object -ExpandProperty Name
                'Feature1.feature', 'Feature2.feature' |
                    ForEach-Object { $FeatureFileNames | Should -Contain $_ }
            }
        }

        Context 'Given a non-standard path ''$PWD/a-different-folder'' containing feature files' {
            It 'Returns 3 feature files under ''$PWD/a-different-folder''' {
                $FeatureFiles = Get-FeatureFile -Path "$PWD/a-different-folder"
                $FeatureFiles | Should -HaveCount 3
                $FeatureFileNames = $FeatureFiles | Select-Object -ExpandProperty Name
                'Feature1.feature', 'Feature2.feature', 'Feature3.feature' |
                    ForEach-Object { $FeatureFileNames | Should -Contain $_ }
            }
        }

        Context 'Given a filename path to a specific feature file' {
            It 'Only returns Feature1.feature' {
                $FeatureFiles = Get-FeatureFile -Path "$PWD/features/Feature1.feature"
                $FeatureFiles | Should -HaveCount 1
                $FeatureFiles.Name | Should -Be 'Feature1.feature'
            }
        }

        Context 'Given a list of paths' {
            It 'Returns 6 feature files' {
                $FeatureFiles = Get-FeatureFile -Path "$PWD/features", "$PWD/a-different-folder"
                $FeatureFiles | Should -HaveCount 6
                # TODO: Need to make this x-plat
                'features\\Feature1\.feature',
                'features\\Feature2\.feature',
                'features\\folder1\\Feature3\.feature',
                'a-different-folder\\Feature1\.feature',
                'a-different-folder\\Feature2\.feature',
                'a-different-folder\\folder1\\Feature3\.feature' |
                    ForEach-Object {
                        $FeatureFile = $_;
                        $FeatureFiles |
                            Where-Object { $_.FullName -match $FeatureFile } |
                            Should -HaveCount 1
                    }
            }
        }
    }
}
