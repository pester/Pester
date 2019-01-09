function Parse-ShouldArgs([object[]] $shouldArgs) {
    if ($null -eq $shouldArgs) {
        $shouldArgs = @()
    }

    $parsedArgs = @{
        PositiveAssertion = $true
        ExpectedValue     = $null
    }

    $assertionMethodIndex = 0
    $expectedValueIndex = 1

    if ($shouldArgs.Count -gt 0 -and $shouldArgs[0] -eq "not") {
        $parsedArgs.PositiveAssertion = $false
        $assertionMethodIndex += 1
        $expectedValueIndex += 1
    }

    if ($assertionMethodIndex -lt $shouldArgs.Count) {
        $parsedArgs.AssertionMethod = "$($shouldArgs[$assertionMethodIndex])"
    }
    else {
        throw 'You cannot call Should without specifying an assertion method.'
    }

    if ($expectedValueIndex -lt $shouldArgs.Count) {
        $parsedArgs.ExpectedValue = $shouldArgs[$expectedValueIndex]
    }

    return $parsedArgs
}

function Get-FailureMessage($assertionEntry, $negate, $value, $expected) {
    if ($negate) {
        $failureMessageFunction = $assertionEntry.GetNegativeFailureMessage
    }
    else {
        $failureMessageFunction = $assertionEntry.GetPositiveFailureMessage
    }

    return (& $failureMessageFunction $value $expected)
}

function New-ShouldErrorRecord ([string] $Message, [string] $File, [string] $Line, [string] $LineText) {
    $exception = & $SafeCommands['New-Object'] Exception $Message
    $errorID = 'PesterAssertionFailed'
    $errorCategory = [Management.Automation.ErrorCategory]::InvalidResult
    # we use ErrorRecord.TargetObject to pass structured information about the error to a reporting system.
    $targetObject = @{Message = $Message; File = $File; Line = $Line; LineText = $LineText}
    $errorRecord = & $SafeCommands['New-Object'] Management.Automation.ErrorRecord $exception, $errorID, $errorCategory, $targetObject
    return $errorRecord
}

function Should {
    <#
    .SYNOPSIS
    Should is a keyword what is used to define an assertion inside It block.

    .DESCRIPTION
    Should is a keyword what is used to define an assertion inside the It block.
    Should provides assertion methods for verify assertion e.g. comparing objects.
    If assertion is not met the test fails and an exception is throwed up.

    Should can be used more than once in the It block if more than one assertion
    need to be verified. Each Should keywords need to be located in a new line.
    Test will be passed only when all assertion will be met (logical conjuction).

    .LINK
    about_Should
    about_Pester
#>

    [CmdletBinding(DefaultParameterSetName = 'Legacy')]
    param (
        [Parameter(ParameterSetName = 'Legacy', Position = 0)]
        [object] $__LegacyArg1,

        [Parameter(ParameterSetName = 'Legacy', Position = 1)]
        [object] $__LegacyArg2,

        [Parameter(ParameterSetName = 'Legacy', Position = 2)]
        [object] $__LegacyArg3,

        [Parameter(ValueFromPipeline = $true)]
        [object] $ActualValue
    )

    dynamicparam {
        Get-AssertionDynamicParams
    }

    begin {
        $inputArray = New-Object System.Collections.Generic.List[PSObject]

        if ($PSCmdlet.ParameterSetName -eq 'Legacy') {
            $parsedArgs = Parse-ShouldArgs ($__LegacyArg1, $__LegacyArg2, $__LegacyArg3)
            $entry = Get-AssertionOperatorEntry -Name $parsedArgs.AssertionMethod
            if ($null -eq $entry) {
                throw "'$($parsedArgs.AssertionMethod)' is not a valid Should operator."
            }
        }
    }

    process {
        $inputArray.Add($ActualValue)
    }

    end {
        $lineNumber = $MyInvocation.ScriptLineNumber
        $lineText = $MyInvocation.Line.TrimEnd("$([System.Environment]::NewLine)")
        $file = $MyInvocation.ScriptName

        if ($PSCmdlet.ParameterSetName -eq 'Legacy') {
            if ($inputArray.Count -eq 0) {
                Invoke-LegacyAssertion $entry $parsedArgs $null $file $lineNumber $lineText
            }
            elseif ($entry.SupportsArrayInput) {
                Invoke-LegacyAssertion $entry $parsedArgs $inputArray.ToArray() $file $lineNumber $lineText
            }
            else {
                foreach ($object in $inputArray) {
                    Invoke-LegacyAssertion $entry $parsedArgs $object $file $lineNumber $lineText
                }
            }
        }
        else {
            $negate = $false
            if ($PSBoundParameters.ContainsKey('Not')) {
                $negate = [bool]$PSBoundParameters['Not']
            }

            $null = $PSBoundParameters.Remove('ActualValue')
            $null = $PSBoundParameters.Remove($PSCmdlet.ParameterSetName)
            $null = $PSBoundParameters.Remove('Not')

            $entry = Get-AssertionOperatorEntry -Name $PSCmdlet.ParameterSetName

            if ($inputArray.Count -eq 0) {
                Invoke-Assertion $entry $PSBoundParameters $null $file $lineNumber $lineText -Negate:$negate
            }
            elseif ($entry.SupportsArrayInput) {
                Invoke-Assertion $entry $PSBoundParameters $inputArray.ToArray() $file $lineNumber $lineText -Negate:$negate
            }
            else {
                foreach ($object in $inputArray) {
                    Invoke-Assertion $entry $PSBoundParameters $object $file $lineNumber $lineText -Negate:$negate
                }
            }
        }
    }
}

function Invoke-LegacyAssertion($assertionEntry, $shouldArgs, $valueToTest, $file, $lineNumber, $lineText) {
    # $expectedValueSplat = @(
    #     if ($null -ne $shouldArgs.ExpectedValue)
    #     {
    #         ,$shouldArgs.ExpectedValue
    #     }
    # )

    $negate = -not $shouldArgs.PositiveAssertion

    $testResult = (& $assertionEntry.Test $valueToTest $shouldArgs.ExpectedValue -Negate:$negate)
    if (-not $testResult.Succeeded) {
        throw ( New-ShouldErrorRecord -Message $testResult.FailureMessage -File $file -Line $lineNumber -LineText $lineText )
    }
}

function Invoke-Assertion {
    param (
        [object] $AssertionEntry,
        [System.Collections.IDictionary] $BoundParameters,
        [object] $valuetoTest,
        [string] $File,
        [int] $LineNumber,
        [string] $LineText,
        [switch] $Negate
    )

    $testResult = & $AssertionEntry.Test -ActualValue $valuetoTest -Negate:$Negate @BoundParameters
    if (-not $testResult.Succeeded) {
        throw ( New-ShouldErrorRecord -Message $testResult.FailureMessage -File $file -Line $lineNumber -LineText $lineText )
    }
    else {
        #extract data to return if there are any on the object
        $data = $testResult.psObject.Properties.Item('Data')
        if ($data) {
            $data.Value
        }
    }
}

function Format-Because ([string] $Because) {
    if ($null -eq $Because) {
        return
    }

    $bcs = $Because.Trim()
    if ([string]::IsNullOrEmpty($bcs)) {
        return
    }

    " because $($bcs -replace 'because\s'),"
}
