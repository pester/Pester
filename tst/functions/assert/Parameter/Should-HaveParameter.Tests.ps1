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
}
