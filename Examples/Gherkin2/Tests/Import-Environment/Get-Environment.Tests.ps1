Set-StrictMode -Version Latest

InModuleScope 'Pester' {
    Describe 'Get-Environment loads the ./features/support/env.ps1 script' -Tag Gherkin {
        # $sessionState = Set-SessionStateHint -PassThru  -Hint 'Caller - Captured in Invoke-Gherkin2' -SessionState $PSCmdlet.SessionState
        # $PesterState = New-PesterState -SessionState $sessionState -Show 'All' -PesterOption $PesterOption

        Context 'A specification suite with an environment script' {
            BeforeAll {
                $CWD = Get-Location -PSProvider FileSystem
            }

            BeforeEach {
                Set-Location '.\Examples\Gherkin2\Tests\Import-Environment\WithEnvironment'
                $PesterState = @{ SessionState = $PSCmdlet.SessionState }
            }

            AfterEach {
                Set-Location $CWD
            }

            Context 'The -WhatIf parameter is specified' {
                It 'Does not import the ./features/support/env.ps1 script' {
                    Get-Environment $PesterState -WhatIf -Verbose
                    $Script:EnvironmentLoaded | Should -BeFalse
                }
            }

            Context 'The -WhatIf parameter is not specified' {
                It 'Imports the ./features/support/env.ps1 script' {
                    Get-Environment $PesterState -Verbose
                    $Script:EnvironmentLoaded | Should -BeTrue
                }
            }
        }

        # Context 'A specification suite without an environment script' {
        #     It 'Does not import any scripts under the ./features/support folder' {

        #     }
        # }
    }
}
