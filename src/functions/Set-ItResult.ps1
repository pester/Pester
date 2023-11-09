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
    Similarly to failing tests, skipped and inconclusive tests should have reason. It allows
    to provide information to the user why the test is neither successful nor failed.

    .EXAMPLE
    ```powershell
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

    .LINK
    https://pester.dev/docs/commands/Set-ItResult
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

    [String]$Message = "is skipped"
    if ($Result -ne 'Skipped') {
        [String]$Because = if ($Because) { $Result.ToUpper(), $Because -join ': ' } else { $Result.ToUpper() }
    }
    if ($Because) {
        [String]$Message += ", because $Because"
    }

    switch ($null) {
        $File {
            [String]$File = $MyInvocation.ScriptName
        }
        $Line {
            [String]$Line = $MyInvocation.ScriptLineNumber
        }
        $LineText {
            [String]$LineText = $MyInvocation.Line.trim()
        }
    }

    switch ($result) {
        'Inconclusive' {
            [String]$errorId = 'PesterTestInconclusive'
        }
        'Pending' {
            [String]$errorId = 'PesterTestPending'
        }
        'Skipped' {
            [String]$errorId = 'PesterTestSkipped'
        }
    }

    throw [Pester.Factory]::CreateErrorRecord(
        $errorId, #string errorId
        $Message, #string message
        $File, #string file
        $Line, #string line
        $LineText, #string lineText
        $false #bool terminating
    )
}
