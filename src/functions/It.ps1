function It {
    <#
.SYNOPSIS
Validates the results of a test inside of a Describe block.

.DESCRIPTION
The It command is intended to be used inside of a Describe or Context Block.
If you are familiar with the AAA pattern (Arrange-Act-Assert), the body of
the It block is the appropriate location for an assert. The convention is to
assert a single expectation for each It block. The code inside of the It block
should throw a terminating error if the expectation of the test is not met and
thus cause the test to fail. The name of the It block should expressively state
the expectation of the test.

In addition to using your own logic to test expectations and throw exceptions,
you may also use Pester's Should command to perform assertions in plain language.

You can intentionally mark It block result as inconclusive by using Set-TestInconclusive
command as the first tested statement in the It block.

.PARAMETER Name
An expressive phrase describing the expected test outcome.

.PARAMETER Test
The script block that should throw an exception if the
expectation of the test is not met.If you are following the
AAA pattern (Arrange-Act-Assert), this typically holds the
Assert.

.PARAMETER Pending
Use this parameter to explicitly mark the test as work-in-progress/not implemented/pending when you
need to distinguish a test that fails because it is not finished yet from a tests
that fail as a result of changes being made in the code base. An empty test, that is a
test that contains nothing except whitespace or comments is marked as Pending by default.

.PARAMETER Skip
Use this parameter to explicitly mark the test to be skipped. This is preferable to temporarily
commenting out a test, because the test remains listed in the output. Use the Strict parameter
of Invoke-Pester to force all skipped tests to fail.

.PARAMETER TestCases
Optional array of hashtable (or any IDictionary) objects.  If this parameter is used,
Pester will call the test script block once for each table in the TestCases array,
splatting the dictionary to the test script block as input.  If you want the name of
the test to appear differently for each test case, you can embed tokens into the Name
parameter with the syntax 'Adds numbers <A> and <B>' (assuming you have keys named A and B
in your TestCases hashtables.)

.PARAMETER Tag
Optional parameter containing an array of strings. When calling Invoke-Pester,
it is possible to include or exclude tests containing the same Tag.

.EXAMPLE
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

.EXAMPLE
```powershell
function Add-Numbers($a, $b) {
    return $a + $b
}

Describe "Add-Numbers" {
    $testCases = @(
        @{ a = 2;     b = 3;       expectedResult = 5 }
        @{ a = -2;    b = -2;      expectedResult = -4 }
        @{ a = -2;    b = 2;       expectedResult = 0 }
        @{ a = 'two'; b = 'three'; expectedResult = 'twothree' }
    )

    It 'Correctly adds <a> and <b> to get <expectedResult>' -TestCases $testCases {
        param ($a, $b, $expectedResult)

        $sum = Add-Numbers $a $b
        $sum | Should -Be $expectedResult
    }
}
```

.LINK
https://github.com/pester/Pester/wiki/It

.LINK
Describe
Context
Set-TestInconclusive
about_should
#>
    [CmdletBinding(DefaultParameterSetName = 'Normal')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Name,

        [Parameter(Position = 1)]
        [ScriptBlock] $Test,

        [Alias("ForEach")]
        [object[]] $TestCases,

        [String[]] $Tag,

        [Parameter(ParameterSetName = 'Pending')]
        [Switch] $Pending,

        [Parameter(ParameterSetName = 'Skip')]
        [Switch] $Skip

        # [Parameter(ParameterSetName = 'Skip')]
        # [String] $SkipBecause,

        # [Switch]$Focus
    )

    $Focus = $false
    if ($PSBoundParameters.ContainsKey('Pending')) {
        $PSBoundParameters.Remove('Pending')

        $Skip = $Pending
        # $SkipBecause = "This test is pending."
    }

    if ($null -eq $Test) {
        if ($Name.Contains("`n")) {
            throw "Test name has multiple lines and no test scriptblock is provided. Did you provide the test name?"
        }
        else {
            throw "No test scriptblock is provided. Did you put the opening curly brace on the next line?"
        }
    }

    if ($PSBoundParameters.ContainsKey('TestCases')) {
        if ($null -ne $TestCases -and 0 -lt @($TestCases).Count) {
            New-ParametrizedTest -Name $Name -ScriptBlock $Test -StartLine $MyInvocation.ScriptLineNumber -Data $TestCases -Tag $Tag -Focus:$Focus -Skip:$Skip
        }
        else {
            # @() or $null is provided do nothing
        }
    }
    else {
        New-Test -Name $Name -ScriptBlock $Test -StartLine $MyInvocation.ScriptLineNumber -Tag $Tag -Focus:$Focus -Skip:$Skip
    }
}
