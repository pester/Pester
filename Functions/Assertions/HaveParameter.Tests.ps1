Set-StrictMode -Version Latest

InModuleScope Pester {

    function Invoke-DummyFunction {
        param(
            [Parameter(Mandatory = $true)]
            $MandatoryParam,

            [DateTime]$SecondParam = (Get-Date),

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
            [String]$ThirdParam = "."
        )
    }

    Describe "Should -HaveParameter" {

        It "passes if the parameter <ParameterName> exists" -TestCases @(
            @{ParameterName = "MandatoryParam"}
            @{ParameterName = "SecondParam"}
            @{ParameterName = "ThirdParam"}
        ) {
            param($ParameterName)
            Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName
        }

        It "passes if the parameter <ParameterName> is mandatory" -TestCases @(
            @{ParameterName = "MandatoryParam"}
        ) {
            param($ParameterName)
            Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -IsMandatory
        }

        It "passes if the parameter <ParameterName> is of type <ExpectedType>" -TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedType = [System.Object]}
            @{ParameterName = "SecondParam"; ExpectedType = [DateTime]}
            @{ParameterName = "ThirdParam"; ExpectedType = [String]}
        ) {
            param($ParameterName, $ExpectedType)
            Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -OfType $ExpectedType
        }

        if ($PSVersionTable.PSVersion.Major -ge 5)
        {
            It "passes if the parameter <ParameterName> has an ArgumentCompleter" -TestCases @(
                @{ParameterName = "ThirdParam"}
            ) {
                param($ParameterName)
                Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -HasArgumentCompleter
            }
        }

        It "passes if the parameter <ParameterName> has a default value '<ExpectedValue>'" -TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedValue = ""}
            @{ParameterName = "SecondParam"; ExpectedValue = "(Get-Date)"}
            @{ParameterName = "ThirdParam"; ExpectedValue = "."}
        ) {
            param($ParameterName, $ExpectedValue)
            Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -Default $ExpectedValue
        }

        It "passes if the parameter <ParameterName> exists, is of type <ExpectedType> and has a default value '<ExpectedValue>'" -TestCases @(
            @{ParameterName = "SecondParam"; ExpectedType = [DateTime]; ExpectedValue = "(Get-Date)"}
            @{ParameterName = "ThirdParam"; ExpectedType = [String]; ExpectedValue = "."}
        ) {
            param($ParameterName, $ExpectedType, $ExpectedValue)
            Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -OfType $ExpectedType -Default $ExpectedValue
        }

        if ($PSVersionTable.PSVersion.Major -ge 5)
        {
            It "passes if the parameter <ParameterName> exists, is of type <ExpectedType>, has a default value '<ExpectedValue>' and has an ArgumentCompleter" -TestCases @(
                @{ParameterName = "ThirdParam"; ExpectedType = [String]; ExpectedValue = "."}
            ) {
                param($ParameterName, $ExpectedType, $ExpectedValue)
                Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -OfType $ExpectedType -Default $ExpectedValue -HasArgumentCompleter
            }
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
            @{ParameterName = "SecondParam"}
            @{ParameterName = "ThirdParam"}
            @{ParameterName = "InputObject"}
        ) {
            param($ParameterName)
            { Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -IsMandatory } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> is not of type <ExpectedType> or does not exist" -TestCases @(
            @{ParameterName = "SecondParam"; ExpectedType = [Int32]}
            @{ParameterName = "ThirdParam"; ExpectedType = [DateTime]}
            @{ParameterName = "InputObject"; ExpectedType = [String]}
        ) {
            param($ParameterName, $ExpectedType)
            { Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -OfType $ExpectedType } | Verify-AssertionFailed
        }

        if ($PSVersionTable.PSVersion.Major -ge 5)
        {
            It "fails if the parameter <ParameterName> has not an ArgumentCompleter or does not exist" -TestCases @(
                @{ParameterName = "MandatoryParam"}
                @{ParameterName = "SecondParam"}
                @{ParameterName = "InputObject"}
            ) {
                param($ParameterName)
                { Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -HasArgumentCompleter } | Verify-AssertionFailed
            }
        }

        It "fails if the parameter <ParameterName> has a default value other than '<ExpectedValue>' or does not exist" -TestCases @(
            @{ParameterName = "SecondParam"; ExpectedValue = "(Get-Item)"}
            @{ParameterName = "ThirdParam"; ExpectedValue = "..\"}
            @{ParameterName = "InputObject"; ExpectedValue = ""}
        ) {
            param($ParameterName, $ExpectedValue)
            { Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -Default $ExpectedValue } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> does not exist, is not of type <ExpectedType> or has a default value other than '<ExpectedValue>'" -TestCases @(
            @{ParameterName = "SecondParam"; ExpectedType = [DateTime]; ExpectedValue = "(Get-Item)"}
            @{ParameterName = "ThirdParam"; ExpectedType = [DateTime]; ExpectedValue = "."}
            @{ParameterName = "InputObject"; ExpectedType = [String]; ExpectedValue = ""}
        ) {
            param($ParameterName, $ExpectedType, $ExpectedValue)
            { Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -OfType $ExpectedType -Default $ExpectedValue } | Verify-AssertionFailed
        }

        if ($PSVersionTable.PSVersion.Major -ge 5)
        {
            It "fails if the parameter <ParameterName> does not exist, is not of type <ExpectedType>, has a default value other than '<ExpectedValue>' or has not an ArgumentCompleter" -TestCases @(
                @{ParameterName = "MandatoryParam"; ExpectedType = [Object]; ExpectedValue = ""}
                @{ParameterName = "SecondParam"; ExpectedType = [DateTime]; ExpectedValue = "."}
                @{ParameterName = "ThirdParam"; ExpectedType = [DateTime]; ExpectedValue = "."}
                @{ParameterName = "InputObject"; ExpectedType = [String]; ExpectedValue = "."}
            ) {
                param($ParameterName, $ExpectedType, $ExpectedValue)
                { Get-Command "Invoke-DummyFunction" | Should -HaveParameter $ParameterName -OfType $ExpectedType -Default $ExpectedValue -HasArgumentCompleter } | Verify-AssertionFailed
            }
        }

        It "returns the correct assertion message when parameter SecondParam is not mandatory" {
            $err = { Get-Command "Invoke-DummyFunction" | Should -HaveParameter SecondParam -IsMandatory } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected command Invoke-DummyFunction to have a parameter SecondParam, which is mandatory, but it wasn't mandatory."
        }

        It "returns the correct assertion message when parameter SecondParam is not mandatory, of the wrong type and has a different default value than expected" {
            $err = { Get-Command "Invoke-DummyFunction" | Should -HaveParameter SecondParam -IsMandatory -OfType [TimeSpan] -Default "wrong value" -Because 'of reasons' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected command Invoke-DummyFunction to have a parameter SecondParam, which is mandatory, of type [TimeSpan] and the default value to be 'wrong value', because of reasons, but it wasn't mandatory, it was of type [DateTime] and the default value was '(Get-Date)'."
        }

        if ($PSVersionTable.PSVersion.Major -ge 5)
        {
            It "returns the correct assertion message when parameter SecondParam is not mandatory, of the wrong type, has a different default value than expected and has no ArgumentCompleter" {
                $err = { Get-Command "Invoke-DummyFunction" | Should -HaveParameter SecondParam -IsMandatory -OfType [TimeSpan] -Default "wrong value" -HasArgumentCompleter -Because 'of reasons' } | Verify-AssertionFailed
                $err.Exception.Message | Verify-Equal "Expected command Invoke-DummyFunction to have a parameter SecondParam, which is mandatory, of type [TimeSpan], the default value to be 'wrong value' and has ArgumentCompletion, because of reasons, but it wasn't mandatory, it was of type [DateTime], the default value was '(Get-Date)' and has no ArgumentCompletion."
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
            @{ParameterName = "FirstParam"}
            @{ParameterName = "SecondParam"}
            @{ParameterName = "InputObject"}
        ) {
            param($ParameterName)
            Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -IsMandatory
        }

        It "passes if the parameter <ParameterName> does not exist, is not mandatory or is not of type <ExpectedType>"-TestCases @(
            @{ParameterName = "SecondParam"; ExpectedType = "[TimeSpan]"}
            @{ParameterName = "ThirdParam"; ExpectedType = "[TimeSpan]"}
            @{ParameterName = "InputObject"; ExpectedType = "[Object]"}
        ) {
            param($ParameterName, $ExpectedType)
            Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -IsMandatory -OfType $ExpectedType
        }

        It "passes if the parameter <ParameterName> does not exist, is not mandatory, is not of type <ExpectedType> or the default value is not <ExpectedValue>"-TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedType = "[TimeSpan]"; ExpectedValue = ""}
            @{ParameterName = "SecondParam"; ExpectedType = "[TimeSpan]"; ExpectedValue = ""}
            @{ParameterName = "ThirdParam"; ExpectedType = "[Int32]"; ExpectedValue = ".."}
            @{ParameterName = "InputObject"; ExpectedType = "[Object]"; ExpectedValue = ""}
        ) {
            param($ParameterName, $ExpectedType, $ExpectedValue)
            Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -OfType $ExpectedType -Default $ExpectedValue
        }

        if ($PSVersionTable.PSVersion.Major -ge 5)
        {
            It "passes if the parameter <ParameterName> does not exist, has not an ArgumentCompleter" -TestCases @(
                @{ParameterName = "SecondParam"}
            ) {
                param($ParameterName)
                Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter -HasArgumentCompleter
            }
        }

        It "fails if the parameter <ParameterName> exists" -TestCases @(
            @{ParameterName = "MandatoryParam"}
            @{ParameterName = "SecondParam"}
        ) {
            param($ParameterName)
            { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> is mandatory" -TestCases @(
            @{ParameterName = "MandatoryParam"}
        ) {
            param($ParameterName)
            { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -IsMandatory } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> is of type <ExpectedType>" -TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedType = [Object]}
            @{ParameterName = "SecondParam"; ExpectedType = [DateTime]}
            @{ParameterName = "ThirdParam"; ExpectedType = [String]}
        ) {
            param($ParameterName, $ExpectedType)
            { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -OfType $ExpectedType } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> is of type <ExpectedType> or the default value is <ExpectedValue>"-TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedType = "[Object]"; ExpectedValue = ""}
            @{ParameterName = "SecondParam"; ExpectedType = "[DateTime]"; ExpectedValue = ""}
            @{ParameterName = "ThirdParam"; ExpectedType = "[String]"; ExpectedValue = ".."}
        ) {
            param($ParameterName, $ExpectedType, $ExpectedValue)
            { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -OfType $ExpectedType -Default $ExpectedValue } | Verify-AssertionFailed
        }

        if ($PSVersionTable.PSVersion.Major -ge 5)
        {
            It "fails if the parameter <ParameterName> has an ArgumentCompleter" -TestCases @(
                @{ParameterName = "ThirdParam"}
            ) {
                param($ParameterName)
                { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -HasArgumentCompleter } | Verify-AssertionFailed
            }
        }

        It "fails if the parameter <ParameterName> has a default value of '<ExpectedValue>'" -TestCases @(
            @{ParameterName = "SecondParam"; ExpectedValue = "(Get-Date)"}
            @{ParameterName = "ThirdParam"; ExpectedValue = "."}
        ) {
            param($ParameterName, $ExpectedValue)
            { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -Default $ExpectedValue } | Verify-AssertionFailed
        }

        It "fails if the parameter <ParameterName> is of type <ExpectedType> or has a default value of '<ExpectedValue>'" -TestCases @(
            @{ParameterName = "MandatoryParam"; ExpectedType = [Object]; ExpectedValue = ""}
            @{ParameterName = "SecondParam"; ExpectedType = [DateTime]; ExpectedValue = "(Get-Date)"}
            @{ParameterName = "ThirdParam"; ExpectedType = [String]; ExpectedValue = "."}
        ) {
            param($ParameterName, $ExpectedType, $ExpectedValue)
            { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -OfType $ExpectedType -Default $ExpectedValue } | Verify-AssertionFailed
        }

        if ($PSVersionTable.PSVersion.Major -ge 5)
        {
            It "fails if the parameter <ParameterName> is of type <ExpectedType>, has a default value of '<ExpectedValue>' or has an ArgumentCompleter" -TestCases @(
                @{ParameterName = "ThirdParam"; ExpectedType = [String]; ExpectedValue = "."}
                @{ParameterName = "ThirdParam"; ExpectedType = [DateTime]; ExpectedValue = "."}
                @{ParameterName = "ThirdParam"; ExpectedType = [DateTime]; ExpectedValue = ".."}
            ) {
                param($ParameterName, $ExpectedType, $ExpectedValue)
                { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter $ParameterName -OfType $ExpectedType -Default $ExpectedValue -HasArgumentCompleter } | Verify-AssertionFailed
            }
        }

        It "returns the correct assertion message when parameter SecondParam is not mandatory" {
            $err = { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter SecondParam -OfType [DateTime] } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected command Invoke-DummyFunction to not have a parameter SecondParam, not of type [datetime], but it was of type [datetime]."
        }

        It "returns the correct assertion message when parameter SecondParam is not mandatory, of the wrong type and has a different default value than expected" {
            $err = { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter MandatoryParam -IsMandatory -OfType [Object] -Default "" -Because 'of reasons' } | Verify-AssertionFailed
            $err.Exception.Message | Verify-Equal "Expected command Invoke-DummyFunction to not have a parameter MandatoryParam, which is not mandatory and not of type [System.Object], because of reasons, but it was mandatory and it was of type [System.Object]."
        }

        if ($PSVersionTable.PSVersion.Major -ge 5)
        {
            It "returns the correct assertion message when parameter SecondParam is not mandatory, of the wrong type, has a different default value than expected and has no ArgumentCompleter" {
                $err = { Get-Command "Invoke-DummyFunction" | Should -Not -HaveParameter ThirdParam -OfType [String] -Default "." -HasArgumentCompleter -Because 'of reasons' } | Verify-AssertionFailed
                $err.Exception.Message | Verify-Equal "Expected command Invoke-DummyFunction to not have a parameter ThirdParam, not of type [string], the default value not to be '.' and has ArgumentCompletion, because of reasons, but it was of type [string], the default value was '.' and has ArgumentCompletion."
            }
        }
    }
}
