Set-StrictMode -Version Latest

InPesterModuleScope {
    Describe "Collect-Input" {
        BeforeAll {
            function Assert-PassThru {
                # This is how all Assert-* functions look inside, here we just collect $Actual and return it.
                [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
                param (
                    [Parameter(ValueFromPipeline = $true)]
                    $Actual,
                    [switch] $UnrollInput
                )

                $collectedInput = Collect-Input -ParameterInput $Actual -PipelineInput $local:Input -IsPipelineInput $MyInvocation.ExpectingInput -UnrollInput:$UnrollInput
                $collectedInput
            }
        }

        Describe "Pipeline input" {
            It "Given `$null through pipeline when unrolling it captures `$null" {
                $collectedInput = $null | Assert-PassThru -UnrollInput

                Verify-True $collectedInput.IsPipelineInput
                if ($null -ne $collectedInput.Actual) {
                    throw "Expected `$null, but got $(Format-Nicely2 $collectedInput.Actual)."
                }
            }

            It "Given `$null through pipeline it captures @(`$null)" {
                $collectedInput = $null | Assert-PassThru -UnrollInput

                Verify-True $collectedInput.IsPipelineInput
                if ($null -ne $collectedInput.Actual) {
                    throw "Expected `$null, but got $(Format-Nicely2 $collectedInput.Actual)."
                }
            }

            It "Given @() through pipeline it captures @()" {
                $collectedInput = @() | Assert-PassThru

                Verify-True $collectedInput.IsPipelineInput
                Verify-Type -Actual $collectedInput.Actual -Expected ([Object[]])
                if (@() -ne $collectedInput.Actual) {
                    throw "Expected @(), but got $(Format-Nicely2 $collectedInput.Actual)."
                }
            }

            It "Given List[int] through pipeline it captures the items in Object[]" {
                $collectedInput = [Collections.Generic.List[int]]@(1, 2) | Assert-PassThru

                Verify-True $collectedInput.IsPipelineInput
                Verify-Type -Actual $collectedInput.Actual -Expected ([Object[]])
                if (1 -ne $collectedInput.Actual[0] -or 2 -ne $collectedInput.Actual[1]) {
                    throw "Expected @(1, 2), but got $(Format-Nicely2 $collectedInput.Actual)."
                }
            }

            It "Given 1,2 through pipeline it captures the items" {
                $collectedInput = 1, 2 | Assert-PassThru

                Verify-True $collectedInput.IsPipelineInput
                Verify-Type -Actual $collectedInput.Actual -Expected ([Object[]])
                if (1 -ne $collectedInput.Actual[0] -or 2 -ne $collectedInput.Actual[1]) {
                    throw "Expected @(1, 2), but got $(Format-Nicely2 $collectedInput.Actual)."
                }
            }
        }

        Describe "Parameter input" {
            It "Given `$null through parameter it captures `$null" {
                $collectedInput = Assert-PassThru -Actual $null

                Verify-False $collectedInput.IsPipelineInput
                if ($null -ne $collectedInput.Actual) {
                    throw "Expected `$null, but got $(Format-Nicely2 $collectedInput.Actual)."
                }
            }

            It "Given @() through parameter it captures @()" {
                $collectedInput = Assert-PassThru -Actual @()

                Verify-False $collectedInput.IsPipelineInput
                Verify-Type -Actual $collectedInput.Actual -Expected ([Object[]])
                if (@() -ne $collectedInput.Actual) {
                    throw "Expected @(), but got $(Format-Nicely2 $collectedInput.Actual)."
                }
            }

            It "Given List[int] through parameter it captures the List" {
                $collectedInput = Assert-PassThru -Actual ([Collections.Generic.List[int]]@(1, 2))

                Verify-False $collectedInput.IsPipelineInput
                Verify-Type -Actual $collectedInput.Actual -Expected ([Collections.Generic.List[int]])
                if (1 -ne $collectedInput.Actual[0] -or 2 -ne $collectedInput.Actual[1]) {
                    throw "Expected List(1, 2), but got $(Format-Nicely2 $collectedInput.Actual)."
                }
            }

            It "Given 1,2 through parameter it captures the items" {
                $collectedInput = Assert-PassThru -Actual 1, 2

                Verify-False $collectedInput.IsPipelineInput
                Verify-Type -Actual $collectedInput.Actual -Expected ([Object[]])
                if (1 -ne $collectedInput.Actual[0] -or 2 -ne $collectedInput.Actual[1]) {
                    throw "Expected @(1, 2), but got $(Format-Nicely2 $collectedInput.Actual)."
                }
            }
        }
    }
}
