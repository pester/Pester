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
    $exception = [Exception] $Message
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
    https://github.com/pester/Pester/wiki/Should

    .LINK
    about_Should
    about_Pester
#>

    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, ValueFromRemainingArguments = $true)]
        [object] $ActualValue
    )

    dynamicparam {
        Get-AssertionDynamicParams
    }

    begin {
        $inputArray = [System.Collections.Generic.List[PSObject]]@()
        $lineNumber = $MyInvocation.ScriptLineNumber
        $lineText = $MyInvocation.Line.TrimEnd("$([System.Environment]::NewLine)")
        $file = $MyInvocation.ScriptName
    }

    process {
        $inputArray.Add($ActualValue)

        $ActualValue
    }

    end {
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

            $assertionParams = @{
                AssertionEntry = $entry
                BoundParameters = $PSBoundParameters
                File = $file
                LineNumber = $lineNumber
                LineText = $lineText
                Negate = $negate
                CallerSessionState = $PSCmdlet.SessionState
                ShouldThrow = ($ErrorActionPreference -eq 'Stop')
            }

            if ($inputArray.Count -eq 0) {
                Invoke-Assertion @assertionParams -ValueToTest $null
            }
            elseif ($entry.SupportsArrayInput) {
                Invoke-Assertion @assertionParams -ValueToTest $inputArray.ToArray()
            }
            else {
                foreach ($object in $inputArray) {
                    Invoke-Assertion @assertionParams -ValueToTest $object
                }
            }
        }
    }
}

function Invoke-Assertion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]
        $AssertionEntry,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]
        $BoundParameters,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $File,

        [Parameter(Mandatory)]
        [int]
        $LineNumber,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $LineText,

        [Parameter(Mandatory)]
        [Management.Automation.SessionState]
        $CallerSessionState,

        [Parameter()]
        [switch]
        $Negate,

        [Parameter()]
        [AllowNull()]
        [object]
        $ValueToTest,

        [Parameter()]
        [boolean]
        $ShouldThrow
    )
    try {
        $testResult = & $AssertionEntry.Test -ActualValue $ValueToTest -Negate:$Negate -CallerSessionState $CallerSessionState @BoundParameters

        if (-not $testResult.Succeeded) {
            $errorRecord = New-ShouldErrorRecord -Message $testResult.FailureMessage -File $file -Line $lineNumber -LineText $lineText

            if ($ShouldThrow) {
                throw $errorRecord
            }

            $currentTest = Get-CurrentTest
            $null = $currentTest.ErrorRecord.Add($errorRecord)
        }
        else {
            #extract data to return if there are any on the object
            $data = $testResult.psObject.Properties.Item('Data')
            if ($data) {
                $data.Value
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
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

function Invoke-LegacyAssertion($assertionEntry, $shouldArgs, $valueToTest, $file, $lineNumber, $lineText) {
    # $expectedValueSplat = @(
    #     if ($null -ne $shouldArgs.ExpectedValue)
    #     {
    #         ,$shouldArgs.ExpectedValue
    #     }
    # )

    # $negate = -not $shouldArgs.PositiveAssertion

    # $testResult = (& $assertionEntry.Test $valueToTest $shouldArgs.ExpectedValue -Negate:$negate)
    # if (-not $testResult.Succeeded) {
    #     throw ( New-ShouldErrorRecord -Message $testResult.FailureMessage -File $file -Line $lineNumber -LineText $lineText )
    # }
}
