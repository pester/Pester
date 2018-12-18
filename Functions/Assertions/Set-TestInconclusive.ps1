function New-InconclusiveErrorRecord ([string] $Message, [string] $File, [string] $Line, [string] $LineText) {
    $exception = New-Object Exception $Message
    $errorID = 'PesterTestInconclusive'
    $errorCategory = [Management.Automation.ErrorCategory]::InvalidResult
    # we use ErrorRecord.TargetObject to pass structured information about the error to a reporting system.
    $targetObject = @{Message = $Message; File = $File; Line = $Line; LineText = $LineText}
    $errorRecord = New-Object Management.Automation.ErrorRecord $exception, $errorID, $errorCategory, $targetObject
    return $errorRecord
}

function Set-TestInconclusive {
<#

    .SYNOPSIS
    Deprecated. Use `Set-ItResult -Inconclusive` instead

    .DESCRIPTION
    Set-TestInconclusive was used inside an It block to mark the test as inconclusive.
    If you need this functionality please use the new Set-ItResult command.

    .PARAMETER Message
    Value assigned to the Message parameter will be displayed in the the test result.

    .EXAMPLE
    Describe "Example" {

        It "My test" {
            Set-TestInconclusive -Message "we forced it to be inconclusive"
        }

    }

    The test result.

    Describing Example
        [?] My test, is inconclusive because we forced it to be inconclusive 58ms

    .LINK
    https://github.com/pester/Pester/wiki/Set%E2%80%90TestInconclusive
#>
    [CmdletBinding()]
    param (
        [string] $Message
    )

    if (!$script:HasAlreadyWarnedAboutDeprecation) {
        Write-Warning 'DEPRECATED: Set-TestInconclusive was deprecated and will be removed in the future. Please update your scripts to use `Set-ItResult -Inconclusive -Because $Message`.'
        $script:HasAlreadyWarnedAboutDeprecation = $true
    }

    Set-ItResult -Inconclusive -Because $Message
}
