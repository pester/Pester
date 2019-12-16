:warning: All information on this page is relevant to Pester v. 3.x. A syntax for Pester v. 4.0 you can find - [[here|Should]].

`Should` is a command that provides assertion convenience methods for comparing objects and throwing test failures when test expectations fail. `Should` is used inside `It` blocks of a Pester test script.

## Negative Assertions

When reviewing the operators listed below, keep in mind that all of them can be negated by putting the word "Not" between "Should" and the operator. For example:

```powershell
$true | Should Be $true
$true | Should Not Be $false
```

## Should Operators

### Be

Compares one object with another for equality and throws if the two objects are not the same. This comparison is not case sensitive.

```powershell
$actual="Actual value"
$actual | Should Be "actual value" # Test will pass
$actual | Should Be "not actual value"  # Test will fail
```

### BeExactly

Compares one object with another for equality and throws if the two objects are not the same. This comparison is case sensitive.

```powershell
$actual="Actual value"
$actual | Should BeExactly "Actual value" # Test will pass
$actual | Should BeExactly "actual value" # Test will fail
```

### BeGreaterThan

Asserts that a number is greater than an expected value. Uses PowerShell's -gt operator to compare the two values.

```powershell
$Error.Count | Should BeGreaterThan 0
```

### BeLessThan

Asserts that a number is less than an expected value. Uses PowerShell's -lt operator to compare the two values.

```powershell
$Error.Count | Should BeLessThan 1
```

### BeLike

Asserts that the actual value matches a wildcard pattern using PowerShell's -like operator. This comparison is not case-sensitive.

```powershell
$actual="Actual value"
$actual | Should BeLike "actual *" # Test will pass
$actual | Should BeLike "not actual *" # Test will fail
```

### BeLikeExactly

Asserts that the actual value matches a wildcard pattern using PowerShell's -like operator. This comparison is case-sensitive.

```powershell
$actual="Actual value"
$actual | Should BeLikeExactly "Actual *" # Test will pass
$actual | Should BeLikeExactly "actual *" # Test will fail
```

### BeOfType

Asserts that the actual value should be an object of a specified type (or a subclass of the specified type) using PowerShell's -is operator:

```powershell
$actual = Get-Item $env:SystemRoot
$actual | Should BeOfType System.IO.DirectoryInfo   # Test will pass; object is a DirectoryInfo
$actual | Should BeOfType System.IO.FileSystemInfo  # Test will pass; DirectoryInfo base class is FileSystemInfo

$actual | Should BeOfType System.IO.FileInfo        # Test will fail; FileInfo is not a base class of DirectoryInfo
```

### Exist

Does not perform any comparison but checks if the object calling Exist is present in a PS Provider. The object must have valid path syntax. It essentially must pass a Test-Path call.

```powershell
$actual=(Dir . )[0].FullName
Remove-Item $actual
$actual | Should Exist # Test will fail
```

To test path containing `[ ]` wildcards, escape each bracket with two back-ticks as such ````"TestDrive:\``[test``].txt"```` or use `Test-Path -LiteralPath $something | Should Be $true`.

### Contain

Checks to see if a file contains the specified text. This search is not case sensitive and uses regular expressions.

```powershell
Set-Content -Path TestDrive:\file.txt -Value 'I am a file'
'TestDrive:\file.txt' | Should Contain 'I Am' # Test will pass
'TestDrive:\file.txt' | Should Contain '^I.*file$' # Test will pass

'TestDrive:\file.txt' | Should Contain 'I Am Not' # Test will fail
```

**Tip:** Use ```[regex]::Escape("pattern")``` to match the exact text.

```powershell
Set-Content -Path TestDrive:\file.txt -Value 'I am a file.'
'TestDrive:\file.txt' | Should Contain 'I.am.a.file' # Test will pass
'TestDrive:\file.txt' | Should Contain ([regex]::Escape('I.am.a.file')) # Test will fail
```

**Warning:** Make sure the input is either a quoted string or and Item object. Otherwise PowerShell will try to invoke the
path, likely throwing an error ```Cannot run a document in the middle of a pipeline```.

```powershell
c:\file.txt |  Should Contain something # Will throw an error
'c:\file.txt' |  Should Contain something # Will evaluate correctly
```

### ContainExactly

Checks to see if a file contains the specified text. This search is case sensitive and uses regular expressions to match the text.

```powershell
Set-Content -Path TestDrive:\file.txt -Value 'I am a file.'
'TestDrive:\file.txt' | Should ContainExactly 'I am' # Test will pass
'TestDrive:\file.txt' | Should ContainExactly 'I Am' # Test will fail
```

### Match

Uses a regular expression to compare two objects. This comparison is not case sensitive.

```powershell
"I am a value" | Should Match "I Am" # Test will pass
"I am a value" | Should Match "I am a bad person" # Test will fail
```

**Tip:** Use ```[regex]::Escape("pattern")``` to match the exact text.

```powershell
"Greg" | Should Match ".reg" # Test will pass
"Greg" | Should Match ([regex]::Escape(".reg")) # Test will fail
```

### MatchExactly

Uses a regular expression to compare two objects. This comparison is case sensitive.

```powershell
"I am a value" | Should MatchExactly "I am" # Test will pass
"I am a value" | Should MatchExactly "I Am" # Test will fail
```

### Throw

Checks if an exception was thrown in the input ScriptBlock. Takes an optional argument to indicate the expected exception message.

```powershell
{ foo } | Should Throw # Test will pass
{ $foo = 1 } | Should Throw # Test will fail
{ foo } | Should Not Throw # Test will fail
{ $foo = 1 } | Should Not Throw # Test will pass
{ throw "This is a test" } | Should Throw "This is a test" # Test will pass
{ throw "bar" } | Should Throw "This is a test" # Test will fail
```

Note: The exception message match is a substring match, so the following assertion will pass:

```powershell
{throw "foo bar baz"} | Should Throw "bar" # Test will pass
```

**Warning:** The input object must be a ScriptBlock, otherwise it is processed outside of the assertion.

```powershell
Get-Process -Name "process" -ErrorAction Stop  | Should Throw # Should pass but fails the test
```

### BeNullOrEmpty

Checks values for null or empty (strings). The static [String]::IsNullOrEmpty() method is used to do the comparison.

```powershell
$null | Should BeNullOrEmpty # Test will pass
$null | Should Not BeNullOrEmpty # Test will fail
@()   | Should BeNullOrEmpty # Test will pass
""    | Should BeNullOrEmpty # Test will pass
```

## Using `Should` in a Test

```powershell
function Add-Numbers($a, $b) {
    return $a + $b
}

Describe "Add-Numbers" {

    It "adds positive numbers" {
        $sum = Add-Numbers 2 3
        $sum | should be 3
    }

    It "ensures that 2 + 2 does not equal 5" {
        $sum = Add-Numbers 2 2
        $sum | should not be 5
    }
}
```

This test will fail since 3 will not be equal to the sum of 2 and 3.
