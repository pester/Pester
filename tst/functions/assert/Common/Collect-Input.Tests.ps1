Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Collect-Input" {
        BeforeAll {
            function Assert-PassThru {
                # This is how all Assert-* functions look inside, here we just collect $Actual and return it.
                [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
                param (
                    [Parameter(ValueFromPipeline = $true)]
                    $Actual
                )


                $Actual = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsInPipeline $MyInvocation.ExpectingInput

                $Actual
            }
        }

        It "Given `$null through pipeline it returns `$null" {
            $in = $null | Assert-PassThru

            Verify-True ($null -eq $in)
        }

        It "Given @() through pipeline it returns array with 0 items" {
            $in = @() | Assert-PassThru

            Verify-True ($in.GetType().Name -eq 'Object[]')
            Verify-True ($in.Count -eq 0)
        }

        It "Given @() through pipeline it returns array with 0 items" {
            $in = Assert-PassThru -Actual @()

            Verify-True ($in.GetType().Name -eq 'Object[]')
            Verify-True ($in.Count -eq 0)
        }

        It "Given @() through pipeline it returns array with 0 items" {
            $in = Assert-PassThru -Actual $null

            Verify-True ($in.GetType().Name -eq 'Object[]')
            Verify-True ($in.Count -eq 0)
        }

        It "Given @() through pipeline it returns array with 0 items" {
            $in = Assert-PassThru -Actual 1, 2

            Verify-True ($in.GetType().Name -eq 'Object[]')
            Verify-True ($in.Count -eq 0)
        }

        It "Given @() through pipeline it returns array with 0 items" {
            $in = 1, 2 | Assert-PassThru

            Verify-True ($in.GetType().Name -eq 'Object[]')
            Verify-True ($in.Count -eq 0)
        }
    }
}
