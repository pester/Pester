function Get-FailureMessage($assertionEntry, $negate, $value, $expected) {
    if ($negate) {
        $failureMessageFunction = $assertionEntry.GetNegativeFailureMessage
    }
    else {
        $failureMessageFunction = $assertionEntry.GetPositiveFailureMessage
    }

    return (& $failureMessageFunction $value $expected)
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
    Test will be passed only when all assertion will be met (logical conjunction).

    .PARAMETER ActualValue
    The actual value that was obtained in the test which should be verified against
    a expected value.

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

    Example of creating a mock for `Get-Command` and asserting that it was called exactly one time.

    .EXAMPLE
    $true | Should -BeFalse

    Asserting that the input value is false. This would fail the test by throwing an error.

    .EXAMPLE
    $a | Should -Be 10

    Asserting that the input value defined in $a is equal to 10.

    .EXAMPLE
    Should -Invoke Get-Command -Times 1 -Exactly

    Asserting that the mocked `Get-Command` was called exactly one time.

    .EXAMPLE
    $user | Should -Not -BeNullOrEmpty

    Asserting that the input value from $user is not null or empty.

    .EXAMPLE
    $planets.Name | Should -Be $Expected

    Asserting that the value of `$planets.Name` is equal to the value defined in `$Expected`.

    .EXAMPLE
    ```powershell
    Context "We want to ensure an exception is thrown when expected" {
        It "Throws the exception" {
            { Get-Application -Name Blarg } | Should -Throw -ExpectedMessage "Application 'Blarg' not found"
        }
    }
    ```

    Asserting that `Get-Application -Name Blarg` will throw an exception with a specific message.

    .LINK
    https://pester.dev/docs/commands/Should

    .LINK
    https://pester.dev/docs/assertions
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

        # first check if we are in the context of Pester, if not we will always throw, and won't disable Should:
        # This check is slightly hacky, here we are reaching out the caller session state and
        # look for $______parameters which we know we are using inside of the Pester runtime to
        # keep the current invocation context, when we find it, we are able to add non-terminating
        # errors without throwing and terminating the test.
        $pesterRuntimeInvocationContext = $PSCmdlet.SessionState.PSVariable.GetValue('______parameters')
        $isInsidePesterRuntime = $null -ne $pesterRuntimeInvocationContext

        if ($isInsidePesterRuntime -and $pesterRuntimeInvocationContext.Configuration.Should.DisableV5.Value) {
            throw "Pester Should -Be syntax is disabled. Use Should-Be (without space), or enable it by setting: `$PesterPreference.Should.DisableV5 = `$false"
        }

        if ($null -eq $shouldThrow -or -not $shouldThrow) {
            # we are sure that we either:
            #    - should not throw because of explicit ErrorAction, and need to figure out a place where to collect the error
            #    - or we don't know what to do yet and need to figure out what to do based on the context and settings
            if (-not $isInsidePesterRuntime) {
                $shouldThrow = $true
            }
            else {
                if ($null -eq $shouldThrow) {
                    if ($null -ne $PSCmdlet.SessionState.PSVariable.GetValue('______isInMockParameterFilter')) {
                        $shouldThrow = $true
                    }
                    else {
                        # ErrorAction was not specified explicitly, figure out what to do from the configuration
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
        $errorRecord = [Pester.Factory]::CreateShouldErrorRecord($testResult.FailureMessage, $file, $lineNumber, $lineText, $shouldThrow, $testResult)

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
