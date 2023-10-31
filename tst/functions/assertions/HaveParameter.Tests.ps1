Set-StrictMode -Version Latest

InPesterModuleScope {

    # not using BeforeAll here, because it does not work in Pester itself
    $global:functionsBlock = {
        if ($PSVersionTable.PSVersion.Major -ge 5) {
            function Invoke-DummyFunction {
                param(
                    [Parameter(Mandatory = $true, ParameterSetName = 'PrimarySet')]
                    [Alias('First', 'Another')]
                    $MandatoryParam,

                    [Parameter(ParameterSetName = 'PrimarySet')]
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
                    [String]$ParamWithArgumentCompleter = "./.git",

                    [Parameter()]
                    [String]$ParamWithRegisteredArgumentCompleter = "./.git"
                )
            }

            Register-ArgumentCompleter -CommandName Invoke-DummyFunction -ParameterName ParamWithRegisteredArgumentCompleter -ScriptBlock {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

                & Get-ChildItem |
                    Where-Object { $_.Name -like "$wordToComplete*" } |
                    ForEach-Object { [System.Management.Automation.CompletionResult]::new( $_.Name, $_.Name, [System.Management.Automation.CompletionResultType]::ParameterValue, $_.Name ) }
            }
        }
        else {
            function Invoke-DummyFunction {
                param(
                    [Parameter(Mandatory = $true, ParameterSetName = 'PrimarySet')]
                    [Alias('First', 'Another')]
                    $MandatoryParam,

                    [Parameter(ParameterSetName = 'PrimarySet')]
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
    }

    Describe "Should -HaveParameter" {
        BeforeAll {
            . $functionsBlock
        }

        It "passes if the parameter <ParameterName> exists" -TestCases @(
            @{ParameterName = "MandatoryParam" }
            @{ParameterName = "ParamWithNotNullOrEmptyValidation" }
            @{ParameterName = "ParamWithScriptValidation" }
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter" }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter" }
            }
        ) {
            Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName
        }

        It "passes if the parameter <ParameterName> is mandatory" -TestCases @(
            @{ParameterName = "MandatoryParam" }
        ) {
            Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -Mandatory
        }

        It "passes if the parameter <ParameterName> is of type <ExpectedType>" -TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedType = [System.Object] }
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedType = [DateTime] }
            @{ParameterName = "ParamWithScriptValidation"; ExpectedType = "String" }
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = "String" }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter"; ExpectedType = "String" }
            }
        ) {
            Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -Type $ExpectedType
        }

        if ($PSVersionTable.PSVersion.Major -ge 5) {
            It "passes if the parameter <ParameterName> has an ArgumentCompleter" -TestCases @(
                @{ParameterName = "ParamWithArgumentCompleter" }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter" }
            ) {
                Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -HasArgumentCompleter
            }
        }

        It "passes if the parameter <ParameterName> has a default value '<ExpectedValue>'" -TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedValue = "" }
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedValue = "(Get-Date)" }
            @{ParameterName = "ParamWithScriptValidation"; ExpectedValue = "." }
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedValue = "./.git" }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter"; ExpectedValue = "./.git" }
            }
        ) {
            Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -DefaultValue $ExpectedValue
        }

        It 'supports validating parameters and default values in functions without param block' {
            function simple ($param1, $param2 = '123') { }
            Get-Command simple | Should -HaveParameter 'param2' -DefaultValue '123'
        }

        It 'supports validating parameters and default values in scripts' {
            Set-Content -Path 'TestDrive:\ShouldHaveParameterTestFile.ps1' -Value 'param([int]$RetryCount = 3)'
            Get-Command 'TestDrive:\ShouldHaveParameterTestFile.ps1' | Should -HaveParameter RetryCount -DefaultValue 3 -Type [int]
        }

        It "passes if the paramblock has opening parenthesis on new line and parameter has a default value" {
            function Test-Paramblock {
                param
                (
                    $Name = 'test'
                )
            }

            Get-Command -Name 'Test-Paramblock' | Should -HaveParameter -ParameterName 'Name' -DefaultValue 'test'
        }

        It "passes if the parameter <ParameterName> exists, is of type <ExpectedType> and has a default value '<ExpectedValue>'" -TestCases @(
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedType = [DateTime]; ExpectedValue = "(Get-Date)" }
            @{ParameterName = "ParamWithScriptValidation"; ExpectedType = [String]; ExpectedValue = "." }
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = "String"; ExpectedValue = "./.git" }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter"; ExpectedType = "String"; ExpectedValue = "./.git" }
            }
        ) {
            Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -Type $ExpectedType -DefaultValue $ExpectedValue
        }

        It 'parameter DefaultValue works when command is provided using resolvable alias' {
            Set-Alias -Name dummyalias -Value Invoke-DummyFunction
            Get-Command dummyalias | Should -HaveParameter ParamWithScriptValidation -DefaultValue "."
        }

        It "passes if the parameter MandatoryParam has an alias 'First'" {
            Get-Command "Invoke-DummyFunction" | Should -HaveParameter MandatoryParam -Alias First
        }

        It "passes if the parameter MandatoryParam has the aliases 'First' and 'Another'" {
            Get-Command "Invoke-DummyFunction" | Should -HaveParameter MandatoryParam -Alias First, Another
        }

        if ($PSVersionTable.PSVersion.Major -ge 5) {
            It "passes if the parameter <ParameterName> exists, is of type <ExpectedType>, has a default value '<ExpectedValue>' and has an ArgumentCompleter" -TestCases @(
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = [String]; ExpectedValue = "./.git" }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter"; ExpectedType = [String]; ExpectedValue = "./.git" }
            ) {
                Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -Type $ExpectedType -DefaultValue $ExpectedValue -HasArgumentCompleter
            }
        }

        It "fails if the command does not have any parameters" {
            { Get-Command "Invoke-EmptyFunction" | Should -HaveParameter "imaginary" } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> does not exists" -TestCases @(
            @{ParameterName = "InputObject" }
            @{ParameterName = "Date" }
            @{ParameterName = "Path" }
        ) {
            { Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> is not mandatory or does not exist" -TestCases @(
            @{ParameterName = "ParamWithNotNullOrEmptyValidation" }
            @{ParameterName = "ParamWithScriptValidation" }
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter" }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter" }

            }
            @{ParameterName = "InputObject" }
        ) {
            { Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -Mandatory } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> is not of type <ExpectedType> or does not exist" -TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedType = [Int32] }
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedType = [Int32] }
            @{ParameterName = "ParamWithScriptValidation"; ExpectedType = [DateTime] }
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = "DateTime" }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter"; ExpectedType = "DateTime" }
            }
            @{ParameterName = "InputObject"; ExpectedType = [String] }
        ) {
            { Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -Type $ExpectedType } | Verify-AssertionFailed
        }

        if ($PSVersionTable.PSVersion.Major -ge 5) {
            It "fails if the parameter <ParameterName> has not an ArgumentCompleter or does not exist" -TestCases @(
                @{ParameterName = "MandatoryParam" }
                @{ParameterName = "ParamWithNotNullOrEmptyValidation" }
                @{ParameterName = "ParamWithScriptValidation" }
                @{ParameterName = "InputObject" }
            ) {
                { Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -HasArgumentCompleter } | Verify-AssertionFailed
            }
        }

        It "fails if the parameter <ParameterName> has a default value other than '<ExpectedValue>' or does not exist" -TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedValue = "." }
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedValue = "(Get-Item)" }
            @{ParameterName = "ParamWithScriptValidation"; ExpectedValue = "" }
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedValue = "." }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter"; ExpectedValue = "." }
            }
            @{ParameterName = "InputObject"; ExpectedValue = "" }
        ) {
            { Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -DefaultValue $ExpectedValue } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> does not exist, is not of type <ExpectedType> or has a default value other than '<ExpectedValue>'" -TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedType = [DateTime]; ExpectedValue = "(Get-Item)" }
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedType = [DateTime]; ExpectedValue = "(Get-Item)" }
            @{ParameterName = "ParamWithScriptValidation"; ExpectedType = [DateTime]; ExpectedValue = "." }
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = "String"; ExpectedValue = "" }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter"; ExpectedType = [String]; ExpectedValue = "" }
            }
            @{ParameterName = "InputObject"; ExpectedType = [String]; ExpectedValue = "" }
        ) {
            { Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -Type $ExpectedType -DefaultValue $ExpectedValue } | Verify-AssertionFailed
        }

        It 'fails if the parameter DefaultValue is used with a binary cmdlet' {
            $err = { Get-Command 'Get-Content' | Should -HaveParameter Force -DefaultValue $False } | Verify-Throw
            $err.Exception.Message | Verify-Equal 'Using -DefaultValue is only supported for functions and scripts.'
        }

        It "fails if the parameter MandatoryParam has no alias 'Second'" {
            { Get-Command "Invoke-DummyFunction" | Should -HaveParameter MandatoryParam -Alias Second } | Verify-AssertionFailed
        }

        It "fails and returns the correct message if the parameter MandatoryParam has no alias 'Second' even though alias 'First' exists" {
            $err = { Get-Command "Invoke-DummyFunction" | Should -HaveParameter MandatoryParam -Alias First, Second } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected command Invoke-DummyFunction to have a parameter MandatoryParam, with aliases 'First' and 'Second', but it didn't have an alias 'Second'."
        }

        It "fails and returns the correct message if the parameter MandatoryParam has no alias 'Second' and no alias 'Third'" {
            $err = { Get-Command "Invoke-DummyFunction" | Should -HaveParameter MandatoryParam -Alias Second, Third } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected command Invoke-DummyFunction to have a parameter MandatoryParam, with aliases 'Second' and 'Third', but it didn't have the aliases 'Second' and 'Third'."
        }

        It "throws ArgumentException when expected type isn't a loaded type" {
            $err = { Get-Command 'Invoke-DummyFunction' | Should -HaveParameter MandatoryParam -Type UnknownType } | Verify-Throw
            $err.Exception | Verify-Type ([ArgumentException])
            # Verify expected type is included in error message
            $err.Exception.Message | Verify-Equal 'Could not find type [UnknownType]. Make sure that the assembly that contains that type is loaded.'
        }

        It "throws ArgumentException when provided ApplicationInfo-object as input value" {
            $err = { Get-Command 'hostname' | Should -HaveParameter MandatoryParam } | Verify-Throw
            $err.Exception | Verify-Type ([ArgumentException])
            $err.Exception.Message | Verify-Equal 'Input value can not be an ApplicationInfo object.'
        }

        if ($PSVersionTable.PSVersion.Major -ge 5) {
            It "fails if the parameter <ParameterName> does not exist, is not of type <ExpectedType>, has a default value other than '<ExpectedValue>' or has not an ArgumentCompleter" -TestCases @(
                @{ParameterName = "MandatoryParam"; ExpectedType = [Object]; ExpectedValue = "" }
                @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedType = [DateTime]; ExpectedValue = "." }
                @{ParameterName = "ParamWithScriptValidation"; ExpectedType = [String]; ExpectedValue = "." }
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = [String]; ExpectedValue = "." }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter"; ExpectedType = [String]; ExpectedValue = "." }
                @{ParameterName = "InputObject"; ExpectedType = [String]; ExpectedValue = "." }
            ) {
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

        It 'passes when object parameter has default parameter value $null' {
            function Test-Parameter {
                param ( [Parameter()] [object] $objParam = $null )
            }

            Get-Command Test-Parameter | Should -HaveParameter 'objParam' -Type 'object' -DefaultValue $null
        }

        It 'passes when integer parameter has default parameter value 0' {
            function Test-Parameter {
                param ( [Parameter()] [int] $intParam = 0 )
            }

            Get-Command Test-Parameter | Should -HaveParameter 'intParam' -Type 'int' -DefaultValue 0
        }

        It 'passes when bool parameter has default parameter value $true' {
            function Test-Parameter {
                param ( [Parameter()] [bool] $boolParam = $true )
            }

            Get-Command Test-Parameter | Should -HaveParameter 'boolParam' -Type 'bool' -DefaultValue $true
        }

        It 'passes when bool parameter has default parameter value $false' {
            function Test-Parameter {
                param ( [Parameter()] [bool] $boolParam = $false )
            }

            Get-Command Test-Parameter | Should -HaveParameter 'boolParam' -Type 'bool' -DefaultValue $false
        }

        if ($PSVersionTable.PSVersion.Major -ge 5) {
            It "returns the correct assertion message when parameter ParamWithNotNullOrEmptyValidation is not mandatory, of the wrong type, has a different default value than expected and has no ArgumentCompleter" {
                $err = { Get-Command "Invoke-DummyFunction" | Should -HaveParameter ParamWithNotNullOrEmptyValidation -Mandatory -Type [TimeSpan] -DefaultValue "wrong value" -HasArgumentCompleter -Because 'of reasons' } | Verify-AssertionFailed
                $err.Exception.Message | Verify-Equal "Expected command Invoke-DummyFunction to have a parameter ParamWithNotNullOrEmptyValidation, which is mandatory, of type [System.TimeSpan], the default value to be 'wrong value' and has ArgumentCompletion, because of reasons, but it wasn't mandatory, it was of type [System.DateTime], the default value was '(Get-Date)' and has no ArgumentCompletion."
            }
        }

        Context 'Using InParameterSet' {
            It "passes if parameter <ParameterName> exist in parameter set <ParameterSetName>" -TestCases @(
                @{ParameterName = 'ParamWithNotNullOrEmptyValidation'; ParameterSetName = 'PrimarySet' }
            ) {
                Get-Command 'Invoke-DummyFunction' | Should -HaveParameter $ParameterName -InParameterSet $ParameterSetName
            }

            It 'passes if parameter <ParameterName> exist in parameter set <ParameterSetName> and is mandatory' -TestCases @(
                @{ParameterName = 'MandatoryParam'; ParameterSetName = 'PrimarySet' }
            ) {
                Get-Command 'Invoke-DummyFunction' | Should -HaveParameter $ParameterName -InParameterSet $ParameterSetName -Mandatory
            }

            It 'fails if parameter <ParameterName> does not exist at all or not in parameter set <ParameterSetName>' -TestCases @(
                @{ParameterName = 'NonExistingParam'; ParameterSetName = 'PrimarySet' }
                @{ParameterName = 'ParamWithNotNullOrEmptyValidation'; ParameterSetName = 'NonExistingSet' }
                @{ParameterName = 'ParamWithScriptValidation'; ParameterSetName = 'PrimarySet' }
            ) {
                $err = { Get-Command 'Invoke-DummyFunction' | Should -HaveParameter $ParameterName -InParameterSet $ParameterSetName } | Verify-AssertionFailed
                $err.Exception.Message | Verify-Equal "Expected command Invoke-DummyFunction to have a parameter $ParameterName in parameter set $ParameterSetName, but the parameter is missing."
            }

            It 'fails if parameter <ParameterName> exists in parameter set <ParameterSetName> but is not mandatory' -TestCases @(
                @{ParameterName = 'ParamWithNotNullOrEmptyValidation'; ParameterSetName = 'PrimarySet' }
            ) {
                $err = { Get-Command 'Invoke-DummyFunction' | Should -HaveParameter $ParameterName -InParameterSet $ParameterSetName -Mandatory } | Verify-AssertionFailed
                $err.Exception.Message | Verify-Equal "Expected command Invoke-DummyFunction to have a parameter $ParameterName in parameter set $ParameterSetName, which is mandatory, but it wasn't mandatory."
            }

            # -InParameterSet only affects if parameter exist and -Mandatory atm. Only appends a filter in the error for the remaining options
        }
    }

    Describe "Should -Not -HaveParameter" {
        BeforeAll {
            . $functionsBlock
        }

        It "passes if the parameter <ParameterName> does not exists" -TestCases @(
            @{ParameterName = "FirstParam" }
            @{ParameterName = "InputObject" }
        ) {
            Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName
        }

        It "passes if the parameter <ParameterName> does not exist or is not mandatory" -TestCases @(
            @{ParameterName = "ParamWithNotNullOrEmptyValidation" }
            @{ParameterName = "ParamWithScriptValidation" }
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter" }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter" }
            }
            @{ParameterName = "InputObject" }
        ) {
            Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -Mandatory
        }

        It "passes if the parameter <ParameterName> does not exist, is not mandatory or is not of type <ExpectedType>"-TestCases @(
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedType = "[TimeSpan]" }
            @{ParameterName = "ParamWithScriptValidation"; ExpectedType = "[TimeSpan]" }
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = [TimeSpan] }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter"; ExpectedType = [Timespan] }
            }
            @{ParameterName = "InputObject"; ExpectedType = "[Object]" }
        ) {
            Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -Mandatory -Type $ExpectedType
        }

        It "passes if the parameter <ParameterName> does not exist, is not mandatory, is not of type <ExpectedType> or the default value is not <ExpectedValue>"-TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedType = "[TimeSpan]"; ExpectedValue = "wrong" }
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedType = "[TimeSpan]"; ExpectedValue = "" }
            @{ParameterName = "ParamWithScriptValidation"; ExpectedType = "[Int32]"; ExpectedValue = ".." }
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = [TimeSpan]; ExpectedValue = "." }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter"; ExpectedType = [TimeSpan]; ExpectedValue = "." }
            }
            @{ParameterName = "InputObject"; ExpectedType = "[Object]"; ExpectedValue = "" }
        ) {
            Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -Type $ExpectedType -DefaultValue $ExpectedValue
        }

        if ($PSVersionTable.PSVersion.Major -ge 5) {
            It "passes if the parameter <ParameterName> does not exist, has not an ArgumentCompleter" -TestCases @(
                @{ParameterName = "MandatoryParam" }
                @{ParameterName = "ParamWithNotNullOrEmptyValidation" }
                @{ParameterName = "ParamWithScriptValidation" }
                @{ParameterName = "InputObject" }
            ) {
                Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter -HasArgumentCompleter
            }
        }

        It "fails if the parameter <ParameterName> exists" -TestCases @(
            @{ParameterName = "MandatoryParam" }
            @{ParameterName = "ParamWithNotNullOrEmptyValidation" }
            @{ParameterName = "ParamWithScriptValidation" }
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter" }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter" }
            }
        ) {
            { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> is mandatory" -TestCases @(
            @{ParameterName = "MandatoryParam" }
        ) {
            { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -Mandatory } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> is of type <ExpectedType>" -TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedType = [Object] }
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedType = [DateTime] }
            @{ParameterName = "ParamWithScriptValidation"; ExpectedType = [String] }
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = "String" }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter"; ExpectedType = "String" }
            }
        ) {
            { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -Type $ExpectedType } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> is of type <ExpectedType> or the default value is <ExpectedValue>"-TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedType = "[Object]"; ExpectedValue = "" }
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedType = "[DateTime]"; ExpectedValue = "" }
            @{ParameterName = "ParamWithScriptValidation"; ExpectedType = "[String]"; ExpectedValue = ".." }
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = [String]; ExpectedValue = "." }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter"; ExpectedType = [String]; ExpectedValue = "." }
            }
        ) {
            { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -Type $ExpectedType -DefaultValue $ExpectedValue } | Verify-AssertionFailed
        }

        if ($PSVersionTable.PSVersion.Major -ge 5) {
            It "fails if the parameter <ParameterName> has an ArgumentCompleter" -TestCases @(
                @{ParameterName = "ParamWithArgumentCompleter" }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter" }
            ) {
                { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -HasArgumentCompleter } | Verify-AssertionFailed
            }
        }

        It "fails if the parameter <ParameterName> has a default value of '<ExpectedValue>'" -TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedValue = "" }
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedValue = "(Get-Date)" }
            @{ParameterName = "ParamWithScriptValidation"; ExpectedValue = "." }
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedValue = "./.git" }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter"; ExpectedValue = "./.git" }
            }
        ) {
            { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -DefaultValue $ExpectedValue } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> is of type <ExpectedType> or has a default value of '<ExpectedValue>'" -TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedType = [Object]; ExpectedValue = "" }
            @{ParameterName = "ParamWithNotNullOrEmptyValidation"; ExpectedType = [DateTime]; ExpectedValue = "(Get-Date)" }
            @{ParameterName = "ParamWithScriptValidation"; ExpectedType = [String]; ExpectedValue = "." }
            if ($PSVersionTable.PSVersion.Major -ge 5) {
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = "String"; ExpectedValue = "./.git" }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter"; ExpectedType = "String"; ExpectedValue = "." }
            }
        ) {
            { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -Type $ExpectedType -DefaultValue $ExpectedValue } | Verify-AssertionFailed
        }

        if ($PSVersionTable.PSVersion.Major -ge 5) {
            It "fails if the parameter <ParameterName> is of type <ExpectedType>, has a default value of '<ExpectedValue>' or has an ArgumentCompleter" -TestCases @(
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = [String]; ExpectedValue = "./.git" }
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = [DateTime]; ExpectedValue = "./.git" }
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = [DateTime]; ExpectedValue = "" }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter"; ExpectedType = [String]; ExpectedValue = "./.git" }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter"; ExpectedType = [DateTime]; ExpectedValue = "./.git" }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter"; ExpectedType = [DateTime]; ExpectedValue = "" }
            ) {
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
            It "returns the correct assertion message when parameter ParamWithNotNullOrEmptyValidation is not mandatory, of the wrong type, has a different default value than expected and has no ArgumentCompleter" -TestCases @(
                @{ParameterName = "ParamWithArgumentCompleter"; ExpectedType = "System.String"; ExpectedValue = "./.git" }
                @{ParameterName = "ParamWithRegisteredArgumentCompleter"; ExpectedType = "System.String"; ExpectedValue = "./.git" }
            ) {
                $err = { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -Type $ExpectedType -DefaultValue $ExpectedValue -HasArgumentCompleter -Because 'of reasons' } | Verify-AssertionFailed
                $err.Exception.Message | Verify-Equal "Expected command Invoke-DummyFunction to not have a parameter $ParameterName, not of type [$ExpectedType], the default value not to be '$ExpectedValue' and has ArgumentCompletion, because of reasons, but it was of type [$ExpectedType], the default value was '$ExpectedValue' and has ArgumentCompletion."
            }
        }

        Context 'Using InParameterSet' {
            It 'passes if parameter <ParameterName> does not exist at all or not in parameter set <ParameterSetName>' -TestCases @(
                @{ParameterName = 'NonExistingParam'; ParameterSetName = 'PrimarySet' }
                @{ParameterName = 'ParamWithScriptValidation'; ParameterSetName = 'PrimarySet' }
                @{ParameterName = 'ParamWithNotNullOrEmptyValidation'; ParameterSetName = 'NonExistingSet' }
            ) {
                Get-Command 'Invoke-DummyFunction' | Should -Not -HaveParameter $ParameterName -InParameterSet $ParameterSetName
            }

            It 'fails if parameter <ParameterName> exist in parameter set <ParameterSetName>' -TestCases @(
                @{ParameterName = 'ParamWithNotNullOrEmptyValidation'; ParameterSetName = 'PrimarySet' }
            ) {
                $err = { Get-Command 'Invoke-DummyFunction' | Should -Not -HaveParameter $ParameterName -InParameterSet $ParameterSetName } | Verify-AssertionFailed
                $err.Exception.Message | Verify-Equal "Expected command Invoke-DummyFunction to not have a parameter $ParameterName in parameter set $ParameterSetName, but the parameter exists."
            }

            # -Not -HaveParameter only supports parameter existing atm. Extend when not mandatory etc is possible.
        }
    }
}

Describe 'Using Should -HaveParameter with alias for local function or mock' {
    # https://github.com/pester/Pester/issues/1431
    It 'throws when testing mock without workaround' {
        function TestFunction($Parameter1) { }
        Mock TestFunction {}

        { Get-Command TestFunction | Should -HaveParameter 'Parameter1' } | Should -Throw -ExpectedMessage "Could not retrieve parameters for mock TestFunction. This is a known issue with Get-Command in PowerShell. Try 'Get-Command TestFunction | Where-Object Parameters | Should -HaveParameter ...'"

        # Verify it works with suggested workaround
        Get-Command TestFunction | Where-Object Parameters | Should -HaveParameter 'Parameter1'
    }

    It 'throws when testing alias for function defined in local script scope' {
        function TestFunction2($Parameter1) { }
        Set-Alias -Name LocalAlias -Value TestFunction2

        { Get-Command LocalAlias | Should -HaveParameter 'Parameter1' } | Should -Throw -ExpectedMessage "Could not retrieve parameters for alias LocalAlias. This is a known issue with Get-Command in PowerShell. Try using the actual command name. For example: 'Get-Command TestFunction2 | Should -HaveParameter ...'"

        # Verify it works with suggested workaround
        Get-Command TestFunction2 | Should -HaveParameter 'Parameter1'
    }
}
