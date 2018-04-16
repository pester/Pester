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

    if (!$script:HasAlreadyWarnedAboutDeprecation) {
        Write-Host '
    DEPRECATION WARNING: It seems you are using Set-TestInconclusive command in your test.
        The command was deprecated and will be removed in the future. Please consider updating
        your scripts to use `Set-ItResult -Inconclusive` instead.
    ' -ForegroundColor "DarkYellow"
        $script:HasAlreadyWarnedAboutDeprecation = $true
    } else {
        $Message = "$Message (DEPRECATED Set-TestInconclusive!)"
    }

    Set-ItResult -Inconclusive -Because $Message
}
