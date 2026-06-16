$script:PesterAssertionContext = $null
$script:PesterAssertionInMockParameterFilter = $false

function Set-PesterAssertionMockParameterFilter {
    param (
        [bool] $IsActive
    )

    $previousState = $script:PesterAssertionInMockParameterFilter
    $script:PesterAssertionInMockParameterFilter = $IsActive

    $previousState
}

function Get-AssertionFailureContext {
    if ($script:PesterAssertionInMockParameterFilter) {
        return @{
            ShouldThrow      = $true
            AddErrorCallback = $null
        }
    }

    $context = $script:PesterAssertionContext
    if ($null -eq $context) {
        return @{
            ShouldThrow      = $true
            AddErrorCallback = $null
        }
    }

    $shouldThrow = 'Stop' -eq $context.Configuration.Should.ErrorAction.Value

    @{
        ShouldThrow      = $shouldThrow
        AddErrorCallback = if ($shouldThrow) { $null } else { $context.AddErrorCallback }
    }
}

function Invoke-AssertionFailed {
    param (
        [Parameter(Mandatory)]
        [string] $Message,

        [Parameter(Mandatory)]
        [Management.Automation.InvocationInfo] $InvocationInfo,

        $ShouldResult
    )

    $failureContext = Get-AssertionFailureContext
    $lineText = if ($null -eq $InvocationInfo.Line) { $null } else { $InvocationInfo.Line.TrimEnd([System.Environment]::NewLine) }
    $errorRecord = [Pester.Factory]::CreateShouldErrorRecord($Message, $InvocationInfo.ScriptName, $InvocationInfo.ScriptLineNumber, $lineText, $failureContext.ShouldThrow, $ShouldResult)

    if ($null -eq $failureContext.AddErrorCallback -or $failureContext.ShouldThrow) {
        throw $errorRecord
    }

    try {
        throw $errorRecord
    }
    catch {
        $errorRecord = $_
    }

    & $failureContext.AddErrorCallback $errorRecord
}
