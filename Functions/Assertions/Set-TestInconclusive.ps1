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
    Set-TestInclusive used inside the It block will cause that the test will be
    considered as inconclusive.

    .DESCRIPTION
    If an Set-TestInconclusive is used inside It block, the test will always fails
    with an Inconclusive result. It's not a passed result, nor a failed result,
    but something in between – Inconclusive. It indicates that the results
    of the test could not be verified.

    .PARAMETER Message
    Value assigned to the Message parameter will be displayed in the the test result.

    .EXAMPLE

    Invoke-Pester

    Describe "Example" {

        It "Test what is inconclusive" {

            Set-TestInconclusive -Message "I'm inconclusive because I can."

        }

    }

    The test result.

    Describing Example
    [?] Test what is inconclusive 96ms
      I'm inconclusive because I can
      at line: 10 in C:\Users\<SOME_FOLDER>\Example.Tests.ps1
      10:         Set-TestInconclusive -Message "I'm inconclusive because I can"
    Tests completed in 408ms
    Tests Passed: 0, Failed: 0, Skipped: 0, Pending: 0, Inconclusive: 1

    .LINK
    https://github.com/pester/Pester/wiki/Set%E2%80%90TestInconclusive
#>
    [CmdletBinding()]
    param (
        [string] $Message
    )

    Assert-DescribeInProgress -CommandName Set-TestInconclusive
    $lineText = $MyInvocation.Line.TrimEnd($([System.Environment]::NewLine))
    $line = $MyInvocation.ScriptLineNumber
    $file = $MyInvocation.ScriptName

    throw ( New-InconclusiveErrorRecord -Message $Message -File $file -Line $line -LineText $lineText)
}
