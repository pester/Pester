Validates the results of a test inside of a `Describe` or `Context` block.

## Description

The `It` command is intended to be used inside of a `Describe` or `Context` Block. If you are familiar with the AAA pattern (Arrange-Act-Assert), the body of the `It` block is the appropriate location for an assert. The convention is to assert a single expectation for each `It` block. The code inside of the `It` block should throw a terminating error if the expectation of the test is not met and thus cause the test to fail. The name of the `It` block should expressively state the expectation of the test.

In addition to using your own logic to test expectations and throw exceptions, you may also use Pester's `Should` commandto perform assertions in plain language.

Possible results of a test are:

- `Passed` - All assertions in the test passed and no terminating exception was thrown from the code.
- `Failed` - An assertion failed, a terminating exception was thrown in the code. The `-Strict` parameter of [[Invoke‐Pester]] was used and the test was Skipped or Pending.
- `Skipped` - The test was explicitly marked with the `-Skip` parameter and `-Strict` parameter of [[Invoke‐Pester]] was not used.
- `Pending` - The test was empty, or was explicitly marked with the `-Pending` parameter, and the `-Strict` parameter of [[Invoke‐Pester]] was not used. An empty test is a test that contains no code, it may contain whitespace, comments or the combination of both.
- `Inconclusive` - The test was intentionally marked as inconclusive by using [[Set‐TestInconclusive]].

## Parameters

#### `Name`

An expressive phrase describing the expected test outcome.

#### `Test`

The script block that should throw an exception if the expectation of the test is not met.  If you are following the AAA pattern (Arrange-Act-Assert), this typically holds the Assert.

#### `TestCases`

Optional array of hashtable (or any IDictionary) objects.  If this parameter is used, Pester will call the test script block once for each table in the TestCases array, splatting the dictionary to the test script block as input.  If you want the name of the test to appear differently for each test case, you can embed tokens into the Name parameter with the syntax "Adds numbers \<A\> and \<B\>" (assuming you have keys named A and B in your TestCases hashtables.)

#### `Skip`

Use this parameter to explicitly mark test to be skipped. This is preferable to temporarily commenting out a test, because the test remains listed in the output. Use the [Strict](https://github.com/pester/Pester/wiki/Invoke-Pester#strict) parameter of [[Invoke‐Pester]] to force all skipped tests to fail.

#### `Pending`

Use this parameter to explicitly mark unfinished tests as pending. This might be useful to distinguish a test that is work-in-progress from tests that fail as a result of a changes being made to the code base.

A test that is empty, contains only comments, or the combination of both will become Pending by default. Use the [Strict](https://github.com/pester/Pester/wiki/Invoke-Pester#strict) parameter of [[Invoke‐Pester]] to force all pending tests to fail.

## Example

```powershell
function Add-Numbers($a, $b) {
    return $a + $b
}

Describe "Add-Numbers" {
    It "adds positive numbers" {
        $sum = Add-Numbers 2 3
        $sum | Should -Be 5
    }

    It "adds negative numbers" {
        $sum = Add-Numbers (-2) (-2)
        $sum | Should -Be (-4)
    }

    It "adds one negative number to positive number" {
        $sum = Add-Numbers (-2) 2
        $sum | Should -Be 0
    }

    It "concatenates strings if given strings" {
        $sum = Add-Numbers two three
        $sum | Should -Be "twothree"
    }
}
```
