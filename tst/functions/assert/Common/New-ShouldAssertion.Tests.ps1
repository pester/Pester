Set-StrictMode -Version Latest

Describe "New-ShouldAssertion" {
    BeforeAll {
        # A representative custom scalar assertion, authored the way a user would, using only the
        # public New-ShouldAssertion surface. It mirrors how the built-in Should-* assertions are
        # written.
        function Should-BeAwesome {
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
            [CmdletBinding()]
            param (
                [Parameter(Position = 1, ValueFromPipeline = $true)]
                $Actual,
                [Parameter(Position = 0)]
                $Expected = 'Awesome',
                [string] $Because
            )

            $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
            $Actual = $assert.Actual()

            if ($Actual -ne $Expected) {
                $assert.Fail("Expected <expected>,<because> but got <actual>.", @{ Expected = $Expected; Because = $Because })
            }
        }

        # A custom collection assertion, to exercise the 'Collection' input kind.
        function Should-BeAwesomeCollection {
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
            [CmdletBinding()]
            param (
                [Parameter(Position = 1, ValueFromPipeline = $true)]
                $Actual,
                [Parameter(Position = 0)]
                $Expected
            )

            $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input -As 'Collection'
            $Actual = $assert.Actual()

            if (-not $assert.IsCollection($Actual)) {
                $assert.Fail("Actual <actual> is not a collection.")
            }
            if ($Actual.Count -ne $Expected.Count) {
                $assert.Fail("Expected <expected> to have the same number of items as <actual>.", @{ Expected = $Expected })
            }
        }
    }

    Context "Passing" {
        It "passes without throwing on a matching value" {
            'Awesome' | Should-BeAwesome
        }

        It "produces no output on a normal pass" {
            $out = @('Awesome' | Should-BeAwesome)
            $out.Count | Verify-Equal 0
        }
    }

    Context "Failing" {
        It "throws a Pester assertion failure" {
            { 'lame' | Should-BeAwesome } | Verify-AssertionFailed
        }

        It "uses the exact PesterAssertionFailed fully-qualified error id" {
            $err = { 'lame' | Should-BeAwesome } | Verify-AssertionFailed
            $err.FullyQualifiedErrorId | Verify-Equal 'PesterAssertionFailed'
        }

        It "does not wrap the terminating error (keeps a plain exception)" {
            $err = { 'lame' | Should-BeAwesome } | Verify-AssertionFailed
            # A method that re-wraps the throw would surface a MethodInvocationException here.
            $err.Exception.GetType().Name | Verify-Equal 'Exception'
        }

        It "substitutes the expected and actual tokens in the message" {
            $err = { 'lame' | Should-BeAwesome } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Like '*Awesome*'
            $err.Exception.Message | Verify-Like '*lame*'
        }

        It "appends the because reason when provided" {
            $err = { 'lame' | Should-BeAwesome -Because 'it should be great' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Like '*because it should be great*'
        }
    }

    Context "Input collection" {
        It "collects a value provided through the pipeline" {
            { 'lame' | Should-BeAwesome } | Verify-AssertionFailed
        }

        It "collects a value provided through the -Actual parameter" {
            { Should-BeAwesome -Actual 'lame' -Expected 'Awesome' } | Verify-AssertionFailed
        }

        It "passes through the -Actual parameter on a match" {
            Should-BeAwesome -Actual 'Awesome' -Expected 'Awesome'
        }

        It "keeps a single piped `$null as a one-item collection for a collection assertion" {
            # Regression: a lone piped $null must not be dropped to an empty collection.
            { $null | Should-BeAwesomeCollection @() } | Verify-AssertionFailed
        }

        It "treats a genuinely piped collection as a collection" {
            1, 2, 3 | Should-BeAwesomeCollection @(1, 2, 3)
        }
    }

    Context "Input hints" {
        It "appends a hint when a multi-item collection is piped into a single-value assertion" {
            $err = { 1, 2, 3 | Should-BeAwesome 3 } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Like '*Hint:*single-value assertion*'
        }

        It "does not append a hint for a plain scalar value" {
            $err = { 'lame' | Should-BeAwesome } | Verify-AssertionFailed
            ($err.Exception.Message -notlike '*Hint:*') | Verify-True
        }
    }

    Context "Message tokens" {
        It "substitutes custom data tokens in the message" {
            function Should-HaveFlavour {
                [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
                [CmdletBinding()]
                param (
                    [Parameter(Position = 1, ValueFromPipeline = $true)] $Actual,
                    [Parameter(Position = 0)] $Expected
                )
                $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
                $Actual = $assert.Actual()
                $assert.Fail("Wanted <flavour> ice cream.", @{ flavour = 'vanilla' })
            }

            $err = { 'x' | Should-HaveFlavour } | Verify-AssertionFailed
            # Data tokens are formatted the same way Pester formats values, so the string is quoted.
            $err.Exception.Message | Verify-Like "*Wanted 'vanilla' ice cream.*"
        }
    }

    Context "Helper methods" {
        It "Format formats a value the way Pester does" {
            function Should-FormatIt {
                [CmdletBinding()] param()
                $assert = New-ShouldAssertion -Caller $PSCmdlet -Buffer $local:Input
                $assert.Format(1)
            }
            Should-FormatIt | Verify-Equal '1'
        }

        It "IsCollection reports whether a value is a collection" {
            function Test-IsCollection {
                [CmdletBinding()] param ($Value)
                $assert = New-ShouldAssertion -Caller $PSCmdlet -Buffer $local:Input
                $assert.IsCollection($Value)
            }
            (Test-IsCollection -Value @(1, 2)) | Verify-True
            (Test-IsCollection -Value 1) | Verify-False
        }

        It "EnsureScalar throws when the expected value is a collection" {
            function Should-CompareScalar {
                [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
                [CmdletBinding()]
                param (
                    [Parameter(Position = 1, ValueFromPipeline = $true)] $Actual,
                    [Parameter(Position = 0)] $Expected
                )
                $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
                $Actual = $assert.Actual()
                $null = $assert.EnsureScalar($Expected)
            }

            $threw = $false
            try { 1 | Should-CompareScalar @(1, 2) } catch { $threw = $true }
            $threw | Verify-True
        }
    }

    Context "Authoring from another module" {
        It "reaches Pester internals from an assertion defined in a separate module" {
            $null = New-Module -Name AwesomeAssertions {
                function Should-BeAwesomeXM {
                    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
                    [CmdletBinding()]
                    param (
                        [Parameter(Position = 1, ValueFromPipeline = $true)] $Actual,
                        [Parameter(Position = 0)] $Expected = 'Awesome'
                    )
                    $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $local:Input
                    $Actual = $assert.Actual()
                    if ($Actual -ne $Expected) {
                        $assert.Fail("Expected <expected> but got <actual>.", @{ Expected = $Expected })
                    }
                }
                Export-ModuleMember -Function Should-BeAwesomeXM
            } | Import-Module -PassThru -Force

            try {
                'Awesome' | Should-BeAwesomeXM
                $err = { 'lame' | Should-BeAwesomeXM } | Verify-AssertionFailed
                $err.Exception.Message | Verify-Like '*Expected*Awesome*but got*lame*'
            }
            finally {
                Remove-Module AwesomeAssertions -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Mock parameter filter" {
        It "matches a mock parameter filter when the custom assertion passes" {
            # Proves an implicit pass reaches the mock: the assertion never calls Pass(), yet the
            # filter still evaluates to true and the mock is used instead of the real function.
            function Get-Thing { [CmdletBinding()] param ([string] $Name) 'real' }
            Mock Get-Thing -MockWith { 'mocked' } -ParameterFilter { $Name | Should-BeAwesome 'Awesome' }

            (Get-Thing -Name 'Awesome') | Verify-Equal 'mocked'
        }

        It "throws (does not silently match) when the custom assertion fails inside a mock parameter filter" {
            # The mirror image of the pass case, matching the built-in Should-* behaviour exactly:
            # a failing assertion in a mock filter is a terminating failure, not a quiet non-match.
            function Get-Thing { [CmdletBinding()] param ([string] $Name) 'real' }
            Mock Get-Thing -MockWith { 'mocked' } -ParameterFilter { $Name | Should-BeAwesome 'Awesome' }

            $err = { Get-Thing -Name 'lame' } | Verify-Throw
            $err.Exception.Message | Verify-Like '*Expected*Awesome*but got*lame*'
        }
    }
}
