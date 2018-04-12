function Set-PesterResult {
<#
    .SYNOPSIS
    Set-PesterResult is used inside the It block to explicitly set the test result

    .DESCRIPTION
    Sometimes a test shouldn't be executed, sometimes the condition cannot be evaluated. 
    By default such tests would typically fail and produce a big read message. 
    Using Set-PesterResult it is possible to set the result from the inside of the It scrip
    block to either inconclusive, or skipped.

    .PARAMETER Inconclusive
    Sets the test result to inconclusive. Cannot be used at the same time as -Skipped

    .PARAMETER Skipped
    Sets the test result to skipped. Cannot be used at the same time as -Inconclusive

    .PARAMETER Because
    Similarily to failing tests, skipped and inconclusive tests should have reason. It allows
    to provide information to the user why the test is neither successful nor failed.

    .EXAMPLE
    Describe "Example" {
        It "This test should have inconclusive result" {
            Set-PesterResult -Inconclusive -Because "we want it to be inconclusive"
        }
    }

    the output should be

    [?] This test should have inconclusive result
      we want it to be inconclusive
      at <ScriptBlock>, Path\To\The\File.Tests.ps1: line 8
      8:        Set-PesterResult -Inconclusive -Because "we want it to be inconclusive"
    Tests completed in 0ms
    Tests Passed: 0, Failed: 0, Skipped: 0, Pending: 0, Inconclusive 1


    .EXAMPLE
    Describe "Example" {
        It "This test should be skipped" {
            Set-PesterResult -Skipped -Because "we want it to be skipped"
        }
    }

    the output should be

    [?] This test should be skipped, because we want it to be skipped
    Tests completed in 0ms
    Tests Passed: 0, Failed: 0, Skipped: 0, Pending: 0, Inconclusive 1
    
#>
    param(
        [switch]$Inconclusive,
        [switch]$Skipped,
        [string]$Because 
    )

    Assert-DescribeInProgress -CommandName Set-PesterResult

    $state = if ($Inconclusive) { "Inconclusive" } else { "Skipped" }
    $exception = New-Object Exception "Test set to $state"
    $errorID = "PesterTest$state"
    $errorCategory = [Management.Automation.ErrorCategory]::InvalidResult

    # we use ErrorRecord.TargetObject to pass structured information about the error to a reporting system.
    $targetObject = @{
        Message = $Because; 
        File = $MyInvocation.ScriptName; 
        Line = $MyInvocation.ScriptLineNumber; 
        LineText = $MyInvocation.Line.TrimEnd($([System.Environment]::NewLine))
    }

    throw New-Object Management.Automation.ErrorRecord $exception, $errorID, $errorCategory, $targetObject
}

























