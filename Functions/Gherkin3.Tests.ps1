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
