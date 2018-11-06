function New-PendingStepErrorRecord ([string] $File, [string] $Line, [string] $LineText) {
    $exception = New-Object Exception "# TODO: (Pester::Pending)"
    $errorID = 'PesterPendingGherkinStep'
    $errorCategory = [Management.Automation.ErrorCategory]::InvalidResult
    # we use ErrorRecord.TargetObject to pass structured information about the error to a reporting system.
    $targetObject = @{Message = $Message; File = $File; Line = $Line; LineText = $LineText}
    $errorRecord = New-Object Management.Automation.ErrorRecord $exception, $errorID, $errorCategory, $targetObject
    return $errorRecord
}

function Set-StepPending {
<#

    .SYNOPSIS
    Set-StepPending used inside Step Definition blocks will cause those steps to be
    considered as pending.

    .DESCRIPTION
    If Set-StepPending is used inside a step definition block, the test will be
    considered as Pending. It's not a passed result, nor a failed result,
    but something in between. It indicates that the results of the test could not
    be verified. A step definition with a Pending result will be considered as
    Inconclusive when output to the NUnitXml report, unless overridden by
    specifying pending and inconclusive tests as failed.

    .EXAMPLE

    Invoke-Gherkin

    Given "this step is not yet implemented" {

        Set-StepPending

    }

    The test result.

    Scenario: Tests with steps using Set-StepPending are pending
      [?] Given this step is not yet implemented 96ms
        # TODO: (Pester::Pending)
        at C:\Users\<SOME_FOLDER>\features\Example.Steps.ps1: line 10
        at C:\Users\<SOME_FOLDER>\features\MyNewFeature.feature: line 10
      [!] When something else 0ms
      [!] Then this should happen 0ms

    1 scenario (1 pending)
    3 steps (2 skipped, 1 pending)
    Tests completed in 408ms

#>
    [CmdletBinding()]
    param ( )

    Assert-DescribeInProgress -CommandName Set-StepPending
    $lineText = $MyInvocation.Line.TrimEnd($([System.Environment]::NewLine))
    $line = $MyInvocation.ScriptLineNumber
    $file = $MyInvocation.ScriptName

    throw ( New-PendingStepErrorRecord -File $file -Line $line -LineText $lineText)
}
