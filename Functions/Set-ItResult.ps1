function Set-ItResult {
    <#
    .SYNOPSIS
    Set-ItResult is used inside the It block to explicitly set the test result

    .DESCRIPTION
    Sometimes a test shouldn't be executed, sometimes the condition cannot be evaluated.
    By default such tests would typically fail and produce a big red message.
    Using Set-ItResult it is possible to set the result from the inside of the It script
    block to either inconclusive, pending or skipped.

    .PARAMETER Inconclusive
    Sets the test result to inconclusive. Cannot be used at the same time as -Pending or -Skipped

    .PARAMETER Pending
    Sets the test result to pending. Cannot be used at the same time as -Inconclusive or -Skipped

    .PARAMETER Skipped
    Sets the test result to skipped. Cannot be used at the same time as -Inconclusive or -Pending

    .PARAMETER Because
    Similarily to failing tests, skipped and inconclusive tests should have reason. It allows
    to provide information to the user why the test is neither successful nor failed.

    .EXAMPLE
    Describe "Example" {
        It "Inconclusive result test" {
            Set-ItResult -Inconclusive -Because "we want it to be inconclusive"
        }
    }

    the output should be

    [?] Inconclusive result test, is inconclusive, because we want it to be inconclusive
    Tests completed in 0ms
    Tests Passed: 0, Failed: 0, Skipped: 0, Pending: 0, Inconclusive 1


    .EXAMPLE
    Describe "Example" {
        It "Skipped test" {
            Set-ItResult -Skipped -Because "we want it to be skipped"
        }
    }

    the output should be

    [!] Skipped test, is skipped, because we want it to be skipped
    Tests completed in 0ms
    Tests Passed: 0, Failed: 0, Skipped: 0, Pending: 0, Inconclusive 1

#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = "Inconclusive")][switch]$Inconclusive,
        [Parameter(Mandatory = $false, ParameterSetName = "Pending")][switch]$Pending,
        [Parameter(Mandatory = $false, ParameterSetName = "Skipped")][switch]$Skipped,
        [string]$Because
    )

    Assert-DescribeInProgress -CommandName Set-ItResult

    $result = $PSCmdlet.ParameterSetName
    $message = "It result set to $result$(if ($Because) { ", $Because" })"
    $data = @{
        Result  = $result
        Because = $Because
    }
    $errorRecord = New-PesterErrorRecord -Result $result  -Message $message -Data $data
    throw $errorRecord
}

function New-PesterErrorRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Result,
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$File,
        [string]$Line,
        [string]$LineText,
        [hashtable]$Data
    )

    $exception = New-Object Exception $Message
    $errorID = "PesterTest$Result"
    $errorCategory = [Management.Automation.ErrorCategory]::InvalidResult

    # we use ErrorRecord.TargetObject to pass structured information about the error to a reporting system.
    $targetObject = @{
        Message  = $Message
        Data     = $Data
        File     = $(if ($File -ne $null) {
                $File
            }
            else {
                $MyInvocation.ScriptName
            })
        Line     = $(if ($Line -ne $null) {
                $Line
            }
            else {
                $MyInvocation.ScriptLineNumber
            })
        LineText = $(if ($LineText -ne $null) {
                $LineText
            }
            else {
                $MyInvocation.Line
            }).TrimEnd($([System.Environment]::NewLine))
    }

    New-Object Management.Automation.ErrorRecord $exception, $errorID, $errorCategory, $targetObject
}
