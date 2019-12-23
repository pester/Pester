function Get-FailureMessage($assertionEntry, $negate, $value, $expected) {
    if ($negate) {
        $failureMessageFunction = $assertionEntry.GetNegativeFailureMessage
    }
    else {
        $failureMessageFunction = $assertionEntry.GetPositiveFailureMessage
    }

    return (& $failureMessageFunction $value $expected)
}

function New-ShouldErrorRecord ([string] $Message, [string] $File, [string] $Line, [string] $LineText, $Terminating) {
    $exception = [Exception] $Message
    $errorID = 'PesterAssertionFailed'
    $errorCategory = [Management.Automation.ErrorCategory]::InvalidResult
    # we use ErrorRecord.TargetObject to pass structured information about the error to a reporting system.
    $targetObject = @{ Message = $Message; File = $File; Line = $Line; LineText = $LineText; Terminating = $Terminating }
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
    }

    process {
        $inputArray.Add($ActualValue)
    }

    end {
        $lineNumber = $MyInvocation.ScriptLineNumber
        $lineText = $MyInvocation.Line.TrimEnd("$([System.Environment]::NewLine)")
        $file = $MyInvocation.ScriptName

        $negate = $false
        if ($PSBoundParameters.ContainsKey('Not')) {
            $negate = [bool]$PSBoundParameters['Not']
        }

        $null = $PSBoundParameters.Remove('ActualValue')
        $null = $PSBoundParameters.Remove($PSCmdlet.ParameterSetName)
        $null = $PSBoundParameters.Remove('Not')

        $entry = Get-AssertionOperatorEntry -Name $PSCmdlet.ParameterSetName

        $errorActionIsDefined = $PSBoundParameters.ContainsKey("ErrorAction")
        $shouldThrowBecauseOfErrorAction = $errorActionIsDefined -and 'Stop' -eq $PSBoundParameters["ErrorAction"]
        if ($errorActionIsDefined) {
            $shouldThrow = $shouldThrowBecauseOfErrorAction
        }
        else {
            # grab the value of ErrorActionPreference from the caller sessionState,
            # doing just $ErrorActionPreference would resolve it to Pester internal session state
            $eap = $PSCmdlet.SessionState.PSVariable.GetValue("ErrorActionPreference")
            $shouldThrowBecauseOfEap = 'Stop' -eq $eap
            $shouldThrow = $shouldThrowBecauseOfEap
        }

        if (-not $shouldThrow) {
            # this is slightly hacky, here we are reaching out the the caller session state and
            # look for $______parameters which we know we are using inside of the Pester runtime to
            # keep the current invocation context, when we find it, we are able to add non-terminating
            # errors without throwing and terminating the test
            $pesterRuntimeInvocationContext =  $PSCmdlet.SessionState.PSVariable.GetValue('______parameters')
            $isInsidePesterRuntime = $null -ne $pesterRuntimeInvocationContext
            $addErrorCallback = if ($isInsidePesterRuntime) {
                # call back into the context we grabbed from the runtime and add this error without throwing
                {
                    param($err)
                    $null = $pesterRuntimeInvocationContext.ErrorRecord.Add($err)
                }
            }
        }

        $assertionParams = @{
            AssertionEntry = $entry
            BoundParameters = $PSBoundParameters
            File = $file
            LineNumber = $lineNumber
            LineText = $lineText
            Negate = $negate
            CallerSessionState = $PSCmdlet.SessionState
            ShouldThrow = -not $isInsidePesterRuntime -or $shouldThrowBecauseOfEap
            AddErrorCallback = $addErrorCallback
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
        $ShouldThrow,

        [ScriptBlock]
        $AddErrorCallback
    )

    $testResult = & $AssertionEntry.Test -ActualValue $ValueToTest -Negate:$Negate -CallerSessionState $CallerSessionState @BoundParameters

    if (-not $testResult.Succeeded) {
        $errorRecord = New-ShouldErrorRecord -Message $testResult.FailureMessage -File $file -Line $lineNumber -LineText $lineText -Terminating $ShouldThrow

        if ($null -eq $AddErrorCallback -or $ShouldThrow) {
            # throw this error to fail the test immediately
            throw $errorRecord
        }

        try {
            # throw and catch to not fail the test, but still have stackTrace
            # alternatively we could call Get-PSStackTrace and format it ourselves
            # in case this turns out too be slow
            throw $errorRecord
        } catch {
            $err = $_
        }

        # collect the error via the provided callback
        & $AddErrorCallback $err
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
