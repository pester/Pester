function Set-ItResult {
    <#
    .SYNOPSIS
    Set-ItResult is used inside the It block to explicitly set the test result

    .DESCRIPTION
    Sometimes a test shouldn't be executed, sometimes the condition cannot be evaluated.
    By default such tests would typically fail and produce a big red message.
    Using Set-ItResult it is possible to set the result from the inside of the It script
    block to either inconclusive, or skipped.

    .PARAMETER Inconclusive
    Sets the test result to inconclusive. Cannot be used at the same time as -Skipped

    .PARAMETER Skipped
    Sets the test result to skipped. Cannot be used at the same time as -Inconclusive.

    .PARAMETER Because
    Similarly to failing tests, skipped and inconclusive tests should have reason. It allows
    to provide information to the user why the test is neither successful nor failed.

    .EXAMPLE
    ```powershell
    Describe "Example" {
        It "Inconclusive test" {
            Set-ItResult -Inconclusive -Because "we want it to be inconclusive"
        }
        It "Skipped test" {
            Set-ItResult -Skipped -Because "we want it to be skipped"
        }
    }
    ```

    the output should be

    ```
    Describing Example
      [?] Inconclusive test is inconclusive, because we want it to be inconclusive 35ms (32ms|3ms)
      [!] Skipped test is skipped, because we want it to be skipped 3ms (2ms|1ms)
    Tests completed in 78ms
    Tests Passed: 0, Failed: 0, Skipped: 1, Inconclusive: 1, NotRun: 0
    ```

    .LINK
    https://pester.dev/docs/commands/Set-ItResult
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = "Inconclusive")][switch]$Inconclusive,
        [Parameter(Mandatory = $false, ParameterSetName = "Skipped")][switch]$Skipped,
        [string]$Because
    )

    Assert-DescribeInProgress -CommandName Set-ItResult

    $result = $PSCmdlet.ParameterSetName

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
            [String]$message = "is inconclusive"
            break
        }
        'Skipped' {
            [String]$errorId = 'PesterTestSkipped'
            [String]$message = "is skipped"
            break
        }
    }

    if ($Because) {
        [String]$message += ", because $(Format-Because $Because)"
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
