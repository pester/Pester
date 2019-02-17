Set-StrictMode -Version Latest

InModuleScope 'Pester' {
    Describe 'Find-EnvironmentScript locates the ./features/support/env.ps1 script' -Tag Gherkin2 {
        BeforeAll {
            $Script:CWD = Get-Location -PSProvider FileSystem
        }

        BeforeEach {
            $Script:GherkinState = [PSCustomObject]@{
                PSTypeName = 'Pester.GherkinState'
                World = $PSCmdlet.SessionState
                Feature = [Gherkin.Ast.Feature[]]$null
                EnvironmentScript = [IO.FileInfo]$null
                SupportScripts = [IO.FileInfo[]]@()
                StepDefinitions = [IO.FileInfo[]]@()
            }
        }

        AfterEach {
            Set-Location $CWD
        }

        Context 'A specification suite with an environment script' {
            It 'The environment script is discovered' {
                Set-Location '.\Examples\Gherkin2\Tests\Find-EnvironmentScript\WithEnvironment'
                Find-EnvironmentScript $GherkinState
                $GherkinState.EnvironmentScript | Should -Not -BeNullOrEmpty
            }
        }

        Context 'A specification suite without an environment script' {
            It 'An environment script is not discovered' {
                Set-Location '.\Examples\Gherkin2\Tests\Find-EnvironmentScript\WithNoEnvironment'
                Find-EnvironmentScript $GherkinState
                $GherkinState.EnvironmentScript | Should -BeNullOrEmpty
            }
        }
    }
}
