This command can be used inside an [[It]] block to explicitly set the test result to be 'Inconclusive'.

- :warning: **As of Pester 4.5.0 the `Set-TestInconclusive` cmdlet is deprecated. You should now use the more flexible `Set-ItResult` cmdlet instead that is described [here](Set‐ItResult)**.

## Description

If `Set-TestInconclusive` is used inside an [[It]] block, the test will return an Inconclusive result. This is not a passed nor failed result, but something in between - Inconclusive. It indicates that the results of the test could not be verified.

You should invoke `Set-TestInconclusive` before any other test inside the `It` block to ensure it returns and inconclusive result. See the below examples for what result occurs if you do not do this:

## Example

```powershell

Describe "Function1" {
    It "Test that always passes" {

        $true | Should -Be $true
        Set-TestInconclusive -Message "I'm inconclusive because I can"
    }

    It "Test that always fails" {

        $true | Should -Be $false
        Set-TestInconclusive -Message "I'm inconclusive because I can"
    }

    It "Test that is inconclusive" {

        Set-TestInconclusive -Message "I'm inconclusive because I can"
    }
}

```

Note, in the above example the function Function1.ps1 is empty (initialized by `New-Fixture`).

## Results

Returned results are:

```powershell
PS >invoke-pester

Executing all tests in <SOME FOLDER>\inconclusive\

Executing script C:\Users\<SOME FOLDER>\inconclusive\Function1.Tests.ps1

  Describing Function1
    [?] Test what always pass 110ms
      I'm inconclusive because I can
      at line: 10 in C:\Users\<SOME FOLDER>\inconclusive\Function1.Tests.ps1
      10:         Set-TestInconclusive -Message "I'm inconclusive because I can"
    [-] Test what always fail 38ms
      Expected: {False}
      But was:  {True}
      at line: 15 in C:\Users\<SOME FOLDER>\inconclusive\Function1.Tests.ps1
      15:         $true | Should -Be $false
    [?] Test what is inconclusive 96ms
      I'm inconclusive because I can
      at line: 25 in C:\Users\<SOME FOLDER>\inconclusive\Function1.Tests.ps1
      25:         Set-TestInconclusive -Message "I'm inconclusive because I can"Tests completed in 245ms
Tests Passed: 0, Failed: 1, Skipped: 0, Pending: 0, Inconclusive: 2
PS >
```

## Explanation

`Set-TestInconclusive` should be the first line of a test, if you want to use it. It blocks are terminated by exceptions, which can be thrown by any command (including `Should` and `Set-TestInconclusive`.) Whichever one throws the error first wins.

So `Set-TestInconclusive` is kind of soft/planned failure for what results are counted as "Inconclusive" result of a test.

Example based on the issue [722](https://github.com/pester/Pester/issues/722).

`Set-TestInconclusive` was introduced as the respond for the issue [395](https://github.com/pester/Pester/issues/395), the pull request [421](https://github.com/pester/Pester/pull/421).
