This command can be used inside an `It` block to explicitly set the test result to either 'Inconclusive', 'Pending' or 'Skipped' along with an optional explanatory message.

- :information_source: **As of Pester 4.5.0 this command replaces the now deprecated `Set-TestInconclusive` cmdlet that is described [here](https://github.com/pester/Pester/wiki/Set%E2%80%90TestInconclusive).**

## Description

Sometimes a test shouldn't be executed, because sometimes the condition cannot be evaluated.
By default such tests would typically fail and produce a big red message.
By using `Set-ItResult` it is possible to set the result from the inside of the `It` script block to either inconclusive, pending or skipped.

## Syntax

```powershell
    Set-ItResult [-Inconclusive] [-Because <String>] [<CommonParameters>]

    Set-ItResult [-Pending] [-Because <String>] [<CommonParameters>]

    Set-ItResult [-Skipped] [-Because <String>] [<CommonParameters>]
```

## Examples

```powershell
Describe 'Set-ItResult Examples' {

    It 'Should ensure the API is working' {

        If ((Get-Date).DayOfWeek -eq 'Monday') {

            Set-ItResult -Inconclusive -Because 'API is down for maintenance on Mondays.'
        }

        $APIResult | Should -Return 'Working'
    }

    It 'Should test $true is $false' {

        If (-not $OppositeDay) {

            Set-ItResult -Skipped -Because 'It is not opposite day'
        }

        $true | Should -Be $false
    }

    It 'Should test version 5 of the API' {

        If ($APIVersion -ne 5) {

            Set-ItResult -Pending -Because 'API v5 not yet available for testing.'

        }
    }
}
```

These examples return:

```powershell
Describing Set-ItResult Examples
  [?] Should ensure the API is working, is inconclusive, because API is down for maintenance on Mondays. 45ms
  [!] Should test $true is $false, is skipped, because It is not opposite day 11ms
  [?] Should test version 5 of the API, is pending, because API v5 not yet available for testing. 23ms

Tests Passed: 0, Failed: 0, Skipped: 1, Pending: 1, Inconclusive 1
```

## Notes

To ensure a consistent result the `Set-ItResult` should be invoked before any other command inside the `It` block that may return a result. In particular commands that return an exception (such as a `Should` that returns a failed result) will result in the test being marked as failed, if `Set-ItResult` is not used first.
