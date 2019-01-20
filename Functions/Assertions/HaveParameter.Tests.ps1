Set-StrictMode -Version Latest

InModuleScope Pester {

    if ($PSVersionTable.PSVersion.Major -ge 5) {
        function Invoke-DummyFunction {
            param(
                [Parameter(Mandatory = $true)]
                $MandatoryParam,

                [ValidateNotNullOrEmpty()]
                [DateTime]$ParamWithNotNullOrEmptyValidation = (Get-Date),

                [Parameter()]
                [ValidateScript(
                    {
                        if (-not (Test-Path $_)) {
                            $errorItem = [System.Management.Automation.ErrorRecord]::new(
                                ([System.ArgumentException]"Path not found"),
                                'ParameterValue.FileNotFound',
                                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                                $_
                            )
                            $errorItem.ErrorDetails = "Invalid path '$_'."
                            $PSCmdlet.ThrowTerminatingError($errorItem)
                        }
                        else {
                            return $true
                        }
                    }
                )]
                [String]$ParamWithScriptValidation = ".",

                [Parameter()]
                [ValidateNotNullOrEmpty()]
                [ArgumentCompleter(
                    {
                        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
                        & Get-ChildItem |
                            Where-Object { $_.Name -like "$wordToComplete*" } |
                            ForEach-Object { [System.Management.Automation.CompletionResult]::new( $_.Name, $_.Name, [System.Management.Automation.CompletionResultType]::ParameterValue, $_.Name ) }
                    }
                )]
                [String]$ParamWithArgumentCompleter = "./.git"
            )
        }
    }
    else {
        function Invoke-DummyFunction {
            param(
                [Parameter(Mandatory = $true)]
                $MandatoryParam,

                [ValidateNotNullOrEmpty()]
                [DateTime]$ParamWithNotNullOrEmptyValidation = (Get-Date),

                # argument completer is PowerShell v5+ only
                [Parameter()]
                [ValidateScript(
                    {
                        if (-not (Test-Path $_)) {
                            $errorItem = [System.Management.Automation.ErrorRecord]::new(
                                ([System.ArgumentException]"Path not found"),
                                'ParameterValue.FileNotFound',
                                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                                $_
                            )
                            $errorItem.ErrorDetails = "Invalid path '$_'."
                            $PSCmdlet.ThrowTerminatingError($errorItem)
                        }
                        else {
                            return $true
                        }
                    }
                )]
                [String]$ParamWithScriptValidation = "."
            )
        }
    }

    function Invoke-EmptyFunction {
        param()
    }

    Describe "Should -HaveParameter" {

        It "passes if the parameter <ParameterName> exists" -TestCases @(
            @{ParameterName = "MandatoryParam"}
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"}
            @{ParameterName = "ParamWithScriptValidation"}
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"}
            }
        ) {
            param($ParameterName)
            Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName
        }

        It "passes if the parameter <ParameterName> is mandatory" -TestCases @(
            @{ParameterName = "MandatoryParam"}
        ) {
            param($ParameterName)
            Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -Mandatory
        }

        It "passes if the parameter <ParameterName> is of type <ExpectedType>" -TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedType = [System.Object]}
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedType = [DateTime]}
            @{ParameterName = "ParamWithScriptValidation"; ExpectedType = "String"}
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = "String"}
            }
        ) {
            param($ParameterName, $ExpectedType)
            Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -Type $ExpectedType
        }

        if ($PSVersionTable.PSVersion.Major -ge 5) {
            It "passes if the parameter <ParameterName> has an ArgumentCompleter" -TestCases @(
                @{ParameterName = "ParamWithArgumentCompleter"}
            ) {
                param($ParameterName)
                Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -HasArgumentCompleter
            }
        }

        It "passes if the parameter <ParameterName> has a default value '<ExpectedValue>'" -TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedValue = ""}
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedValue = "(Get-Date)"}
            @{ParameterName = "ParamWithScriptValidation"; ExpectedValue = "."}
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedValue = "./.git"}
            }
        ) {
            param($ParameterName, $ExpectedValue)
            Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -DefaultValue $ExpectedValue
        }

        It "passes if the parameter <ParameterName> exists, is of type <ExpectedType> and has a default value '<ExpectedValue>'" -TestCases @(
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedType = [DateTime]; ExpectedValue = "(Get-Date)"}
            @{ParameterName = "ParamWithScriptValidation"; ExpectedType = [String]; ExpectedValue = "."}
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = "String"; ExpectedValue = "./.git"}
            }
        ) {
            param($ParameterName, $ExpectedType, $ExpectedValue)
            Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -Type $ExpectedType -DefaultValue $ExpectedValue
        }

        if ($PSVersionTable.PSVersion.Major -ge 5) {
            It "passes if the parameter <ParameterName> exists, is of type <ExpectedType>, has a default value '<ExpectedValue>' and has an ArgumentCompleter" -TestCases @(
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = [String]; ExpectedValue = "./.git"}
            ) {
                param($ParameterName, $ExpectedType, $ExpectedValue)
                Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -Type $ExpectedType -DefaultValue $ExpectedValue -HasArgumentCompleter
            }
        }

        It "fails if the command does not have any parameters" {
            { Get-Command "Invoke-EmptyFunction" | Should -HaveParameter "imaginary" } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> does not exists" -TestCases @(
            @{ParameterName = "InputObject"}
            @{ParameterName = "Date"}
            @{ParameterName = "Path"}
        ) {
            param($ParameterName)
            { Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> is not mandatory or does not exist" -TestCases @(
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"}
            @{ParameterName = "ParamWithScriptValidation"}
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"}
            }
            @{ParameterName = "InputObject"}
        ) {
            param($ParameterName)
            { Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -Mandatory } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> is not of type <ExpectedType> or does not exist" -TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedType = [Int32]}
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedType = [Int32]}
            @{ParameterName = "ParamWithScriptValidation"; ExpectedType = [DateTime]}
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = "DateTime"}
            }
            @{ParameterName = "InputObject"; ExpectedType = [String]}
        ) {
            param($ParameterName, $ExpectedType)
            { Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -Type $ExpectedType } | Verify-AssertionFailed
        }

        if ($PSVersionTable.PSVersion.Major -ge 5) {
            It "fails if the parameter <ParameterName> has not an ArgumentCompleter or does not exist" -TestCases @(
                @{ParameterName = "MandatoryParam"}
                @{ParameterName = "ParamWithNotNullOrEmptyValidation"}
                @{ParameterName = "ParamWithScriptValidation"}
                @{ParameterName = "InputObject"}
            ) {
                param($ParameterName)
                { Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -HasArgumentCompleter } | Verify-AssertionFailed
            }
        }

        It "fails if the parameter <ParameterName> has a default value other than '<ExpectedValue>' or does not exist" -TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedValue = "."}
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedValue = "(Get-Item)"}
            @{ParameterName = "ParamWithScriptValidation"; ExpectedValue = ""}
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedValue = "."}
            }
            @{ParameterName = "InputObject"; ExpectedValue = ""}
        ) {
            param($ParameterName, $ExpectedValue)
            { Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -DefaultValue $ExpectedValue } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> does not exist, is not of type <ExpectedType> or has a default value other than '<ExpectedValue>'" -TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedType = [DateTime]; ExpectedValue = "(Get-Item)"}
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedType = [DateTime]; ExpectedValue = "(Get-Item)"}
            @{ParameterName = "ParamWithScriptValidation"; ExpectedType = [DateTime]; ExpectedValue = "."}
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = "String"; ExpectedValue = ""}
            }
            @{ParameterName = "InputObject"; ExpectedType = [String]; ExpectedValue = ""}
        ) {
            param($ParameterName, $ExpectedType, $ExpectedValue)
            { Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -Type $ExpectedType -DefaultValue $ExpectedValue } | Verify-AssertionFailed
        }

        if ($PSVersionTable.PSVersion.Major -ge 5) {
            It "fails if the parameter <ParameterName> does not exist, is not of type <ExpectedType>, has a default value other than '<ExpectedValue>' or has not an ArgumentCompleter" -TestCases @(
                @{ParameterName = "MandatoryParam"; ExpectedType = [Object]; ExpectedValue = ""}
                @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedType = [DateTime]; ExpectedValue = "."}
                @{ParameterName = "ParamWithScriptValidation"; ExpectedType = [String]; ExpectedValue = "."}
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = [String]; ExpectedValue = "."}
                @{ParameterName = "InputObject"; ExpectedType = [String]; ExpectedValue = "."}
            ) {
                param($ParameterName, $ExpectedType, $ExpectedValue)
                { Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -Type $ExpectedType -DefaultValue $ExpectedValue -HasArgumentCompleter } | Verify-AssertionFailed
            }
        }

        It "returns the correct assertion message when the command does not have any parameters" {
            $err = { Get-Command "Invoke-EmptyFunction" | Should -HaveParameter "imaginary" } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected command Invoke-EmptyFunction to have a parameter imaginary, but the parameter is missing."
        }

        It "returns the correct assertion message when parameter ParamWithNotNullOrEmptyValidation is not mandatory" {
            $err = { Get-Command "Invoke-DummyFunction" | Should -HaveParameter ParamWithNotNullOrEmptyValidation -Mandatory } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected command Invoke-DummyFunction to have a parameter ParamWithNotNullOrEmptyValidation, which is mandatory, but it wasn't mandatory."
        }

        It "returns the correct assertion message when parameter ParamWithNotNullOrEmptyValidation is not mandatory, of the wrong type and has a different default value than expected" {
            $err = { Get-Command "Invoke-DummyFunction" | Should -HaveParameter ParamWithNotNullOrEmptyValidation -Mandatory -Type [TimeSpan] -DefaultValue "wrong value" -Because 'of reasons' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected command Invoke-DummyFunction to have a parameter ParamWithNotNullOrEmptyValidation, which is mandatory, of type [System.TimeSpan] and the default value to be 'wrong value', because of reasons, but it wasn't mandatory, it was of type [System.DateTime] and the default value was '(Get-Date)'."
        }

        if ($PSVersionTable.PSVersion.Major -ge 5) {
            It "returns the correct assertion message when parameter ParamWithNotNullOrEmptyValidation is not mandatory, of the wrong type, has a different default value than expected and has no ArgumentCompleter" {
                $err = { Get-Command "Invoke-DummyFunction" | Should -HaveParameter ParamWithNotNullOrEmptyValidation -Mandatory -Type [TimeSpan] -DefaultValue "wrong value" -HasArgumentCompleter -Because 'of reasons' } | Verify-AssertionFailed
                $err.Exception.Message | Verify-Equal "Expected command Invoke-DummyFunction to have a parameter ParamWithNotNullOrEmptyValidation, which is mandatory, of type [System.TimeSpan], the default value to be 'wrong value' and has ArgumentCompletion, because of reasons, but it wasn't mandatory, it was of type [System.DateTime], the default value was '(Get-Date)' and has no ArgumentCompletion."
            }
        }
    }

    Describe "Should -Not -HavePameter" {

        It "passes if the parameter <ParameterName> does not exists" -TestCases @(
            @{ParameterName = "FirstParam"}
            @{ParameterName = "InputObject"}
        ) {
            param($ParameterName)
            Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName
        }

        It "passes if the parameter <ParameterName> does not exist or is not mandatory" -TestCases @(
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"}
            @{ParameterName = "ParamWithScriptValidation"}
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"}
            }
            @{ParameterName = "InputObject"}
        ) {
            param($ParameterName)
            Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -Mandatory
        }

        It "passes if the parameter <ParameterName> does not exist, is not mandatory or is not of type <ExpectedType>"-TestCases @(
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedType = "[TimeSpan]"}
            @{ParameterName = "ParamWithScriptValidation"; ExpectedType = "[TimeSpan]"}
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = [TimeSpan]}
            }
            @{ParameterName = "InputObject"; ExpectedType = "[Object]"}
        ) {
            param($ParameterName, $ExpectedType)
            Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -Mandatory -Type $ExpectedType
        }

        It "passes if the parameter <ParameterName> does not exist, is not mandatory, is not of type <ExpectedType> or the default value is not <ExpectedValue>"-TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedType = "[TimeSpan]"; ExpectedValue = "wrong"}
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedType = "[TimeSpan]"; ExpectedValue = ""}
            @{ParameterName = "ParamWithScriptValidation"; ExpectedType = "[Int32]"; ExpectedValue = ".."}
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = [TimeSpan]; ExpectedValue = "."}
            }
            @{ParameterName = "InputObject"; ExpectedType = "[Object]"; ExpectedValue = ""}
        ) {
            param($ParameterName, $ExpectedType, $ExpectedValue)
            Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -Type $ExpectedType -DefaultValue $ExpectedValue
        }

        if ($PSVersionTable.PSVersion.Major -ge 5) {
            It "passes if the parameter <ParameterName> does not exist, has not an ArgumentCompleter" -TestCases @(
                @{ParameterName = "MandatoryParam"}
                @{ParameterName = "ParamWithNotNullOrEmptyValidation"}
                @{ParameterName = "ParamWithScriptValidation"}
                @{ParameterName = "InputObject"}
            ) {
                param($ParameterName)
                Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter -HasArgumentCompleter
            }
        }

        It "fails if the parameter <ParameterName> exists" -TestCases @(
            @{ParameterName = "MandatoryParam"}
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"}
            @{ParameterName = "ParamWithScriptValidation"}
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"}
            }
        ) {
            param($ParameterName)
            { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> is mandatory" -TestCases @(
            @{ParameterName = "MandatoryParam"}
        ) {
            param($ParameterName)
            { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -Mandatory } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> is of type <ExpectedType>" -TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedType = [Object]}
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedType = [DateTime]}
            @{ParameterName = "ParamWithScriptValidation"; ExpectedType = [String]}
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = "String"}
            }
        ) {
            param($ParameterName, $ExpectedType)
            { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -Type $ExpectedType } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> is of type <ExpectedType> or the default value is <ExpectedValue>"-TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedType = "[Object]"; ExpectedValue = ""}
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedType = "[DateTime]"; ExpectedValue = ""}
            @{ParameterName = "ParamWithScriptValidation"; ExpectedType = "[String]"; ExpectedValue = ".."}
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = [String]; ExpectedValue = "."}
            }
        ) {
            param($ParameterName, $ExpectedType, $ExpectedValue)
            { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -Type $ExpectedType -DefaultValue $ExpectedValue } | Verify-AssertionFailed
        }

        if ($PSVersionTable.PSVersion.Major -ge 5) {
            It "fails if the parameter <ParameterName> has an ArgumentCompleter" -TestCases @(
                @{ParameterName = "ParamWithArgumentCompleter"}
            ) {
                param($ParameterName)
                { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -HasArgumentCompleter } | Verify-AssertionFailed
            }
        }

        It "fails if the parameter <ParameterName> has a default value of '<ExpectedValue>'" -TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedValue = ""}
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedValue = "(Get-Date)"}
            @{ParameterName = "ParamWithScriptValidation"; ExpectedValue = "."}
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedValue = "./.git"}
            }
        ) {
            param($ParameterName, $ExpectedValue)
            { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -DefaultValue $ExpectedValue } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> is of type <ExpectedType> or has a default value of '<ExpectedValue>'" -TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedType = [Object]; ExpectedValue = ""}
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedType = [DateTime]; ExpectedValue = "(Get-Date)"}
            @{ParameterName = "ParamWithScriptValidation"; ExpectedType = [String]; ExpectedValue = "."}
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = "String"; ExpectedValue = "./.git"}
            }
        ) {
            param($ParameterName, $ExpectedType, $ExpectedValue)
            { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -Type $ExpectedType -DefaultValue $ExpectedValue } | Verify-AssertionFailed
        }

        if ($PSVersionTable.PSVersion.Major -ge 5) {
            It "fails if the parameter <ParameterName> is of type <ExpectedType>, has a default value of '<ExpectedValue>' or has an ArgumentCompleter" -TestCases @(
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = [String]; ExpectedValue = "./.git"}
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = [DateTime]; ExpectedValue = "./.git"}
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = [DateTime]; ExpectedValue = ""}

            ) {
                param($ParameterName, $ExpectedType, $ExpectedValue)
                { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -Type $ExpectedType -DefaultValue $ExpectedValue -HasArgumentCompleter } | Verify-AssertionFailed
            }
        }

        It "returns the correct assertion message when parameter ParamWithNotNullOrEmptyValidation is not mandatory" {
            $err = { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter ParamWithNotNullOrEmptyValidation -Type [DateTime] } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected command Invoke-DummyFunction to not have a parameter ParamWithNotNullOrEmptyValidation, not of type [System.DateTime], but it was of type [System.DateTime]."
        }

        It "returns the correct assertion message when parameter ParamWithNotNullOrEmptyValidation is not mandatory, of the wrong type and has a different default value than expected" {
            $err = { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter MandatoryParam -Mandatory -Type [Object] -DefaultValue "" -Because 'of reasons' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected command Invoke-DummyFunction to not have a parameter MandatoryParam, which is not mandatory, not of type [System.Object] and the default value not to be <empty>, because of reasons, but it was mandatory, it was of type [System.Object] and the default value was <empty>."
        }

        if ($PSVersionTable.PSVersion.Major -ge 5) {
            It "returns the correct assertion message when parameter ParamWithNotNullOrEmptyValidation is not mandatory, of the wrong type, has a different default value than expected and has no ArgumentCompleter" {
                $err = { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter ParamWithArgumentCompleter -Type [String] -DefaultValue "./.git" -HasArgumentCompleter -Because 'of reasons' } | Verify-AssertionFailed
                $err.Exception.Message | Verify-Equal "Expected command Invoke-DummyFunction to not have a parameter ParamWithArgumentCompleter, not of type [System.String], the default value not to be './.git' and has ArgumentCompletion, because of reasons, but it was of type [System.String], the default value was './.git' and has ArgumentCompletion."
            }
        }
    }
}
