function Set-ItResult {
    <#
    .SYNOPSIS
    Set-ItResult is used inside the It block to explicitly set the test result

    .DESCRIPTION
    Sometimes a test shouldn't be executed, sometimes the condition cannot be evaluated.
    By default such tests would typically fail and produce a big red message.
    Using Set-ItResult it is possible to set the result from the inside of the It script
    block to either inconclusive, pending or skipped.

    As of Pester 5, there is no "Inconclusive" or "Pending" test state, so all tests will now go to state skipped,
    however the test result notes will include information about being inconclusive or testing to keep this command
    backwards compatible

    .PARAMETER Inconclusive
    **DEPRECATED** Sets the test result to inconclusive. Cannot be used at the same time as -Pending or -Skipped

    .PARAMETER Pending
    **DEPRECATED** Sets the test result to pending. Cannot be used at the same time as -Inconclusive or -Skipped

    .PARAMETER Skipped
    Sets the test result to skipped. Cannot be used at the same time as -Inconclusive or -Pending

    .PARAMETER Because
    Similarily to failing tests, skipped and inconclusive tests should have reason. It allows
    to provide information to the user why the test is neither successful nor failed.

    .EXAMPLE
    ```ps
    Describe "Example" {
        It "Skipped test" {
            Set-ItResult -Skipped -Because "we want it to be skipped"
        }
    }
    ```

    the output should be

    ```
    [!] Skipped test is skipped, because we want it to be skipped
    Tests completed in 0ms
    Tests Passed: 0, Failed: 0, Skipped: 0, Pending: 0, Inconclusive 1
    ```
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

    #TODO: Remove in Pester 6
    if ($result -in 'Inconclusive','Pending') {
        Write-Host -Fore Yellow 'DEPRECATION WARNING: Inconclusive and Pending states are deprecated in Pester 5. You should update Set-ItResult in your tests to use -Skipped only'
        [String]$Because = $result.toUpper() + ': ' + $Because
    }

    $test.Result = 'Skipped'
    $test.Data.Because = $Because
    throw [Management.Automation.RuntimeException]'Skipped'
}
