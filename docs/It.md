---
external help file: Pester-help.xml
Module Name: Pester
online version:
schema: 2.0.0
---

# It

## SYNOPSIS
Validates the results of a test inside of a Describe block.

## SYNTAX

### Normal (Default)
```
It [-name] <String> [[-test] <ScriptBlock>] [-TestCases <IDictionary[]>] [<CommonParameters>]
```

### Pending
```
It [-name] <String> [[-test] <ScriptBlock>] [-TestCases <IDictionary[]>] [-Pending] [<CommonParameters>]
```

### Skip
```
It [-name] <String> [[-test] <ScriptBlock>] [-TestCases <IDictionary[]>] [-Skip] [<CommonParameters>]
```

## DESCRIPTION
The It command is intended to be used inside of a Describe or Context Block.
If you are familiar with the AAA pattern (Arrange-Act-Assert), the body of
the It block is the appropriate location for an assert.
The convention is to
assert a single expectation for each It block.
The code inside of the It block
should throw a terminating error if the expectation of the test is not met and
thus cause the test to fail.
The name of the It block should expressively state
the expectation of the test.

In addition to using your own logic to test expectations and throw exceptions,
you may also use Pester's Should command to perform assertions in plain language.

You can intentionally mark It block result as inconclusive by using Set-TestInconclusive
command as the first tested statement in the It block.

## EXAMPLES

### EXAMPLE 1
```
function Add-Numbers($a, $b) {
```

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

### EXAMPLE 2
```
function Add-Numbers($a, $b) {
```

return $a + $b
}

Describe "Add-Numbers" {
    $testCases = @(
        @{ a = 2;     b = 3;       expectedResult = 5 }
        @{ a = -2;    b = -2;      expectedResult = -4 }
        @{ a = -2;    b = 2;       expectedResult = 0 }
        @{ a = 'two'; b = 'three'; expectedResult = 'twothree' }
    )

    It 'Correctly adds \<a\> and \<b\> to get \<expectedResult\>' -TestCases $testCases {
        param ($a, $b, $expectedResult)

        $sum = Add-Numbers $a $b
        $sum | Should -Be $expectedResult
    }
}

## PARAMETERS

### -name
An expressive phrase describing the expected test outcome.

```yaml
Type: System.String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -test
The script block that should throw an exception if the
expectation of the test is not met.If you are following the
AAA pattern (Arrange-Act-Assert), this typically holds the
Assert.

```yaml
Type: System.Management.Automation.ScriptBlock
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: {}
Accept pipeline input: False
Accept wildcard characters: False
```

### -TestCases
Optional array of hashtable (or any IDictionary) objects. 
If this parameter is used,
Pester will call the test script block once for each table in the TestCases array,
splatting the dictionary to the test script block as input. 
If you want the name of
the test to appear differently for each test case, you can embed tokens into the Name
parameter with the syntax 'Adds numbers \<A\> and \<B\>' (assuming you have keys named A and B
in your TestCases hashtables.)

```yaml
Type: System.Collections.IDictionary[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Pending
Use this parameter to explicitly mark the test as work-in-progress/not implemented/pending when you
need to distinguish a test that fails because it is not finished yet from a tests
that fail as a result of changes being made in the code base.
An empty test, that is a
test that contains nothing except whitespace or comments is marked as Pending by default.

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: Pending
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Skip
Use this parameter to explicitly mark the test to be skipped.
This is preferable to temporarily
commenting out a test, because the test remains listed in the output.
Use the Strict parameter
of Invoke-Pester to force all skipped tests to fail.

```yaml
Type: System.Management.Automation.SwitchParameter
Parameter Sets: Skip
Aliases: Ignore

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS

[Describe
Context
Set-TestInconclusive
about_should]()

