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
    # $lineNumber, $lineText, $file and $addErrorCallback are consumed by Test-AssertionResult
    # through dynamic scoping, which the analyzer cannot see.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, ValueFromRemainingArguments = $true)]
        [object] $ActualValue
    )

    dynamicparam {
        # Inlined Get-AssertionDynamicParams (whose whole body is `return $script:AssertionDynamicParams`)
        # to save a function-call frame in the dynamicparam block, which PowerShell evaluates on every Should call.
        $script:AssertionDynamicParams
    }

    begin {
        $inputArray = [System.Collections.Generic.List[PSObject]]@()
    }

    process {
        $inputArray.Add($ActualValue)
    }

    end {
        # [int]/[string] typed to mirror the parameter types of Invoke-Assertion, whose body is inlined
        # below; notably a $null ScriptName becomes '' exactly like binding $null to a [string] parameter,
        # which keeps the "$null -eq $currentFile" fallback in Test-AssertionResult unreachable, as before.
        [int] $lineNumber = $MyInvocation.ScriptLineNumber
        [string] $lineText = $MyInvocation.Line.TrimEnd([System.Environment]::NewLine)
        [string] $file = $MyInvocation.ScriptName

        $negate = $false
        if ($PSBoundParameters.ContainsKey('Not')) {
            $negate = [bool]$PSBoundParameters['Not']
        }

        $null = $PSBoundParameters.Remove('ActualValue')
        $null = $PSBoundParameters.Remove($PSCmdlet.ParameterSetName)
        $null = $PSBoundParameters.Remove('Not')

        # Inlined Get-AssertionOperatorEntry (whose whole body is `return $script:AssertionOperators[$Name]`)
        # to save a function-call frame per assertion. Should is a module function, so $script: resolves to
        # the same module scope the helper reads.
        $entry = $script:AssertionOperators[$PSCmdlet.ParameterSetName]

        $shouldThrow = $null
        # always defined so the dynamic-scope read in Test-AssertionResult (called below without the
        # former Invoke-Assertion parameter layer) finds it even when no callback is set up
        $addErrorCallback = $null
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

        if (-not $entry) { return }

        # The Invoke-Assertion body is inlined below: its 12-parameter binding (Mandatory + validation
        # attributes) plus the splat hashtable cost ~100us per assertion, roughly half of a passing
        # `Should -Be`. Test-AssertionResult keeps reading $file/$lineNumber/$lineText/$shouldThrow/
        # $addErrorCallback from this scope via dynamic scoping, exactly as it read the equally-named
        # Invoke-Assertion parameters before. Invoke-Assertion itself stays defined for other callers.
        $callerSessionState = $PSCmdlet.SessionState

        if ($inputArray.Count -eq 0) {
            $testResult = & $entry.Test -ActualValue $null -Negate:$negate -CallerSessionState $callerSessionState @PSBoundParameters
            Test-AssertionResult $testResult
        }
        elseif ($entry.SupportsArrayInput) {
            if ($MyInvocation.ExpectingInput) {
                # Pipeline input is collected item-by-item in the process block, so pass the collected array.
                $testResult = & $entry.Test -ActualValue ($inputArray.ToArray()) -Negate:$negate -CallerSessionState $callerSessionState @PSBoundParameters
                Test-AssertionResult $testResult
            }
            else {
                # The value was supplied by parameter instead (Should -ActualValue @(1,2,3), which is also what
                # splatting does). The process block ran once and $inputArray wrapped the whole value into a
                # single element; enumerate the original $ActualValue with @() so it matches what the pipeline
                # would have produced, rather than being wrapped one level too deep. (#2314)
                $testResult = & $entry.Test -ActualValue (@($ActualValue)) -Negate:$negate -CallerSessionState $callerSessionState @PSBoundParameters
                Test-AssertionResult $testResult
            }
        }
        else {
            foreach ($object in $inputArray) {
                $testResult = & $entry.Test -ActualValue $object -Negate:$negate -CallerSessionState $callerSessionState @PSBoundParameters
                Test-AssertionResult $testResult
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

    Test-AssertionResult $testResult
}

function Test-AssertionResult {
    param (
        $TestResult
    )

    if (-not $TestResult.Succeeded) {
        $currentFile = $file
        $currentLineNumber = $lineNumber
        $currentLineText = $lineText
        $currentShouldThrow = $ShouldThrow
        $currentAddErrorCallback = $AddErrorCallback

        if ($null -eq $currentFile -and $null -ne $PSCmdlet) {
            $pesterRuntimeInvocationContext = $PSCmdlet.SessionState.PSVariable.GetValue('______parameters')
            $isInsidePesterRuntime = $null -ne $pesterRuntimeInvocationContext

            $errorActionIsDefined = $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('ErrorAction')
            if ($errorActionIsDefined) {
                $currentShouldThrow = 'Stop' -eq $PSCmdlet.MyInvocation.BoundParameters['ErrorAction']
            }

            if ($null -eq $currentShouldThrow -or -not $currentShouldThrow) {
                if (-not $isInsidePesterRuntime) {
                    $currentShouldThrow = $true
                }
                else {
                    if ($null -eq $currentShouldThrow) {
                        if ($null -ne $PSCmdlet.SessionState.PSVariable.GetValue('______isInMockParameterFilter')) {
                            $currentShouldThrow = $true
                        }
                        else {
                            $currentShouldThrow = 'Stop' -eq $pesterRuntimeInvocationContext.Configuration.Should.ErrorAction.Value
                        }
                    }

                    if (-not $currentShouldThrow) {
                        $currentAddErrorCallback = {
                            param($err)
                            $null = $pesterRuntimeInvocationContext.ErrorRecord.Add($err)
                        }
                    }
                }
            }

            $currentFile = $PSCmdlet.MyInvocation.ScriptName
            $currentLineNumber = $PSCmdlet.MyInvocation.ScriptLineNumber
            $currentLineText = $PSCmdlet.MyInvocation.Line
            if ($null -ne $currentLineText) {
                $currentLineText = $currentLineText.TrimEnd([System.Environment]::NewLine)
            }
        }

        $errorRecord = [Pester.Factory]::CreateShouldErrorRecord($TestResult.FailureMessage, $currentFile, $currentLineNumber, $currentLineText, $currentShouldThrow, $TestResult)

        if ($null -eq $currentAddErrorCallback -or $currentShouldThrow) {
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
        & $currentAddErrorCallback $err
    }
    else {
        #extract data to return if there are any on the object
        $data = $TestResult.psObject.Properties.Item('Data')
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
