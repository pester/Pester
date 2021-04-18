﻿function Get-FailureMessage($assertionEntry, $negate, $value, $expected) {
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
    Should is a keyword that is used to define an assertion inside an It block.

    .DESCRIPTION
    Should is a keyword that is used to define an assertion inside an It block.
    Should provides assertion methods to verify assertions e.g. comparing objects.
    If assertion is not met the test fails and an exception is thrown.

    Should can be used more than once in the It block if more than one assertion
    need to be verified. Each Should keyword needs to be on a separate line.
    Test will be passed only when all assertion will be met (logical conjuction).

    .PARAMETER ActualValue
    The actual value that was obtained in the test which should be verified against
    a expected value.

    .LINK
    https://pester.dev/docs/commands/Should

    .LINK
    https://pester.dev/docs/usage/assertions

    .LINK
    about_Should

    .LINK
    about_Pester

    .EXAMPLE
    ```powershell
    Describe "d1" {
        BeforeEach { $be = 1 }
        It "i1" {
            $be = 2
        }
        AfterEach { Write-Host "AfterEach: $be" }
    }
    ```

    .EXAMPLE
    ```powershell
    Describe "d1" {
        It "i1" {
            $user = Get-User
            $user | Should -NotBeNullOrEmpty -ErrorAction Stop
            $user |
                Should -HaveProperty Name -Value "Jakub" |
                Should -HaveProperty Age  -Value 30
        }
    }
    ```

    .EXAMPLE
    ```powershell
    Describe "d1" {
        It "i1" {
            Mock Get-Command { }
            Get-Command -CommandName abc
            Should -Invoke Get-Command -Times 1 -Exactly
        }
    }
    ```

    .EXAMPLE
    ```powershell
    Describe "d1" {
        It "i1" {
            Mock Get-Command { }
            Get-Command -CommandName abc
            Should -Invoke Get-Command -Times 1 -Exactly
        }
    }
    ```

    .EXAMPLE
    $true | Should -BeFalse

    .EXAMPLE
    $a | Should -Be 10

    .EXAMPLE
    Should -Invoke Get-Command -Times 1 -Exactly

    .EXAMPLE
    $user | Should -NotBeNullOrEmpty -ErrorAction Stop

    .EXAMPLE
    $planets.Name | Should -Be $Expected
#>

    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, ValueFromRemainingArguments = $true)]
        [object] $ActualValue
    )

    dynamicparam {
        # Figuring out if we are using the old syntax is 'easy'
        # we can use $myInvocation.Line to get the surrounding context
        $myLine = if ($null -ne $MyInvocation -and 0 -le ($MyInvocation.OffsetInLine - 1)) {
            $MyInvocation.Line.Substring($MyInvocation.OffsetInLine - 1)
        }

        # A bit of Regex lets us know if the line used the old form
        if ($myLine -match '^\s{0,}should\s{1,}(?<Operator>[^\-\@\s]+)')
        {
            $shouldErrorMsg = "Legacy Should syntax (without dashes) is not supported in Pester 5. Please refer to migration guide at: https://pester.dev/docs/migrations/v3-to-v4"
            throw $shouldErrorMsg
        } else {
            Get-AssertionDynamicParams
        }
    }

    begin {
        $inputArray = [System.Collections.Generic.List[PSObject]]@()
    }

    process {
        $inputArray.Add($ActualValue)
    }

    end {
        $lineNumber = $MyInvocation.ScriptLineNumber
        $lineText = $MyInvocation.Line.TrimEnd([System.Environment]::NewLine)
        $file = $MyInvocation.ScriptName

        $negate = $false
        if ($PSBoundParameters.ContainsKey('Not')) {
            $negate = [bool]$PSBoundParameters['Not']
        }

        $null = $PSBoundParameters.Remove('ActualValue')
        $null = $PSBoundParameters.Remove($PSCmdlet.ParameterSetName)
        $null = $PSBoundParameters.Remove('Not')

        $entry = Get-AssertionOperatorEntry -Name $PSCmdlet.ParameterSetName

        $shouldThrow = $null
        $errorActionIsDefined = $PSBoundParameters.ContainsKey("ErrorAction")
        if ($errorActionIsDefined) {
            $shouldThrow = 'Stop' -eq $PSBoundParameters["ErrorAction"]
        }

        if ($null -eq $shouldThrow -or -not $shouldThrow) {
            # we are sure that we either:
            #    - should not throw because of explicit ErrorAction, and need to figure out a place where to collect the error
            #    - or we don't know what to do yet and need to figure out what to do based on the context and settings

            # first check if we are in the context of Pester, if not we will always throw:
            # this is slightly hacky, here we are reaching out the the caller session state and
            # look for $______parameters which we know we are using inside of the Pester runtime to
            # keep the current invocation context, when we find it, we are able to add non-terminating
            # errors without throwing and terminating the test
            $pesterRuntimeInvocationContext = $PSCmdlet.SessionState.PSVariable.GetValue('______parameters')
            $isInsidePesterRuntime = $null -ne $pesterRuntimeInvocationContext
            if (-not $isInsidePesterRuntime) {
                $shouldThrow = $true
            }
            else {
                if ($null -eq $shouldThrow) {
                    if ($null -ne $PSCmdlet.SessionState.PSVariable.GetValue('______isInMockParameterFilter')) {
                        $shouldThrow = $true
                    } else {
                        # ErrorAction was not specified explictily, figure out what to do from the configuration
                        $shouldThrow = 'Stop' -eq $pesterRuntimeInvocationContext.Configuration.Should.ErrorAction.Value
                    }
                }

                # here the $ShouldThrow is set from one of multiple places, either as override from -ErrorAction or
                # the settings, or based on the Pester runtime availability
                if (-not $shouldThrow) {
                    # call back into the context we grabbed from the runtime and add this error without throwing
                    $addErrorCallback = {
                        param($err)
                        $null = $pesterRuntimeInvocationContext.ErrorRecord.Add($err)
                    }
                }
            }
        }

        $assertionParams = @{
            AssertionEntry     = $entry
            BoundParameters    = $PSBoundParameters
            File               = $file
            LineNumber         = $lineNumber
            LineText           = $lineText
            Negate             = $negate
            CallerSessionState = $PSCmdlet.SessionState
            ShouldThrow        = $shouldThrow
            AddErrorCallback   = $addErrorCallback
        }

        if (-not $entry) { return }

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
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object]
        $AssertionEntry,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]
        $BoundParameters,

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
        $errorRecord = [Pester.Factory]::CreateShouldErrorRecord($testResult.FailureMessage, $file, $lineNumber, $lineText, $shouldThrow)


        if ($null -eq $AddErrorCallback -or $ShouldThrow) {
            # throw this error to fail the test immediately
            throw $errorRecord
        }

        try {
            # throw and catch to not fail the test, but still have stackTrace
            # alternatively we could call Get-PSStackTrace and format it ourselves
            # in case this turns out too be slow
            throw $errorRecord
        }
        catch {
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
