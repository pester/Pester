function Invoke-AssertionFailed {
    param (
        [Parameter(Mandatory)]
        [string] $Message,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet] $CallerCmdlet,

        $Expected,
        $Actual,
        [string] $Because,
        [switch] $Pretty
    )

    $newShouldErrorRecordParameters = @{}
    if ($PSBoundParameters.ContainsKey('Expected')) { $newShouldErrorRecordParameters.Expected = $Expected }
    if ($PSBoundParameters.ContainsKey('Actual')) { $newShouldErrorRecordParameters.Actual = $Actual }
    if ($PSBoundParameters.ContainsKey('Because')) { $newShouldErrorRecordParameters.Because = $Because }
    if ($PSBoundParameters.ContainsKey('Pretty')) { $newShouldErrorRecordParameters.Pretty = $Pretty }

    $pesterRuntimeInvocationContext = $CallerCmdlet.SessionState.PSVariable.GetValue('______parameters')
    $isInsidePesterRuntime = $null -ne $pesterRuntimeInvocationContext

    $shouldThrow = $null
    $errorActionIsDefined = $CallerCmdlet.MyInvocation.BoundParameters.ContainsKey('ErrorAction')
    if ($errorActionIsDefined) {
        $shouldThrow = 'Stop' -eq $CallerCmdlet.MyInvocation.BoundParameters['ErrorAction']
    }

    $addErrorCallback = $null

    if ($null -eq $shouldThrow -or -not $shouldThrow) {
        if (-not $isInsidePesterRuntime) {
            $shouldThrow = $true
        }
        else {
            if ($null -eq $shouldThrow) {
                if ($null -ne $CallerCmdlet.SessionState.PSVariable.GetValue('______isInMockParameterFilter')) {
                    $shouldThrow = $true
                }
                else {
                    $shouldThrow = 'Stop' -eq $pesterRuntimeInvocationContext.Configuration.Should.ErrorAction.Value
                }
            }

            if (-not $shouldThrow) {
                $addErrorCallback = {
                    param($err)
                    $null = $pesterRuntimeInvocationContext.ErrorRecord.Add($err)
                }
            }
        }
    }

    $errorRecord = New-ShouldErrorRecord -Message $Message -Invocation $CallerCmdlet.MyInvocation -Terminating:$shouldThrow @newShouldErrorRecordParameters

    if ($shouldThrow) {
        throw $errorRecord
    }

    try { throw $errorRecord } catch { $errorRecord = $_ }
    & $addErrorCallback $errorRecord
}