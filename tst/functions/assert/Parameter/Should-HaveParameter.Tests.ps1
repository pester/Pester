Set-StrictMode -Version Latest

Describe "Should-HaveParameter" {
    It "Passes when function has a parameter" {
        function f ($a) { }

        Get-Command f | Should-HaveParameter a
    }

    It "Fails when function does not have a parameter" {
        function f () { }

        { Get-Command f | Should-HaveParameter a } | Verify-Throw
    }

    Context "Mandatory" {
        It "Fails when parameter does not exist and -Mandatory is specified" {
            function f () { }

            { Get-Command f | Should-HaveParameter a -Mandatory } | Verify-Throw
        }

        It "Fails when parameter exists but is not mandatory" {
            function f ($a) { }

            { Get-Command f | Should-HaveParameter a -Mandatory } | Verify-Throw
        }

        It "Passes when parameter exists and is mandatory" {
            function f {
                param(
                    [Parameter(Mandatory)]
                    $a
                )
            }

            Get-Command f | Should-HaveParameter a -Mandatory
        }

        It "Fails when parameter does not exist and -Mandatory:`$false is specified" {
            function f () { }

            { Get-Command f | Should-HaveParameter a -Mandatory:$false } | Verify-Throw
        }

        It "Fails when parameter exists and is mandatory but -Mandatory:`$false is specified" {
            function f {
                param(
                    [Parameter(Mandatory)]
                    $a
                )
            }

            { Get-Command f | Should-HaveParameter a -Mandatory:$false } | Verify-Throw
        }

        It "Passes when parameter exists and is not mandatory with -Mandatory:`$false" {
            function f ($a) { }

            Get-Command f | Should-HaveParameter a -Mandatory:$false
        }
    }

    Context "HasArgumentCompleter" {
        It "Fails when parameter does not exist and -HasArgumentCompleter is specified" {
            function f () { }

            { Get-Command f | Should-HaveParameter a -HasArgumentCompleter } | Verify-Throw
        }

        It "Fails when parameter exists but has no argument completer" {
            function f ($a) { }

            { Get-Command f | Should-HaveParameter a -HasArgumentCompleter } | Verify-Throw
        }

        It "Passes when parameter exists and has argument completer" {
            function f {
                param(
                    [ArgumentCompleter({ @('one', 'two') })]
                    $a
                )
            }

            Get-Command f | Should-HaveParameter a -HasArgumentCompleter
        }

        It "Fails when parameter does not exist and -HasArgumentCompleter:`$false is specified" {
            function f () { }

            { Get-Command f | Should-HaveParameter a -HasArgumentCompleter:$false } | Verify-Throw
        }

        It "Fails when parameter has argument completer but -HasArgumentCompleter:`$false is specified" {
            function f {
                param(
                    [ArgumentCompleter({ @('one', 'two') })]
                    $a
                )
            }

            { Get-Command f | Should-HaveParameter a -HasArgumentCompleter:$false } | Verify-Throw
        }

        It "Passes when parameter exists and has no argument completer with -HasArgumentCompleter:`$false" {
            function f ($a) { }

            Get-Command f | Should-HaveParameter a -HasArgumentCompleter:$false
        }
    }

    Context "DefaultValueType" {
        It "Passes when the default value is an expression and Expression is expected" {
            function f {
                param([string] $Path = (Get-Date))
            }

            Get-Command f | Should-HaveParameter Path -DefaultValueType Expression
        }

        It "Passes when the default value is a literal string and its type is expected" {
            function f {
                param([string] $Path = '(Get-Date)')
            }

            Get-Command f | Should-HaveParameter Path -DefaultValueType String
            Get-Command f | Should-HaveParameter Path -DefaultValueType ([string])
        }

        It "Reports the real type, so a `$true default is [bool] and a number is [int]" {
            function f {
                param($Enabled = $true, $Retries = 3)
            }

            Get-Command f | Should-HaveParameter Enabled -DefaultValueType ([bool])
            Get-Command f | Should-HaveParameter Retries -DefaultValueType int
        }

        It "Distinguishes a string-literal default from an expression default" {
            function f {
                param(
                    [string] $Literal = '(Get-Date)',
                    [string] $Expression = (Get-Date)
                )
            }

            # Same -DefaultValue string, different -DefaultValueType (issue #1888)
            Get-Command f | Should-HaveParameter Literal -DefaultValue '(Get-Date)' -DefaultValueType String
            Get-Command f | Should-HaveParameter Expression -DefaultValue '(Get-Date)' -DefaultValueType Expression
        }

        It "Fails when the default value type does not match" {
            function f {
                param([string] $Path = '(Get-Date)')
            }

            { Get-Command f | Should-HaveParameter Path -DefaultValueType Expression } | Verify-Throw
        }

        It "Fails when the parameter has no default value" {
            function f {
                param([string] $Path)
            }

            { Get-Command f | Should-HaveParameter Path -DefaultValueType String } | Verify-Throw
        }

        It "Throws when given a type name that does not exist" {
            function f {
                param([string] $Path = '(Get-Date)')
            }

            { Get-Command f | Should-HaveParameter Path -DefaultValueType NotAType } | Verify-Throw
        }
    }
}
