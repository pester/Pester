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

.PARAMETER Name
An expressive phsae describing the expected test outcome.

.PARAMETER Test
The script block that should throw an exception if the
expectation of the test is not met.If you are following the
AAA pattern (Arrange-Act-Assert), this typically holds the
Assert.

.PARAMETER TestCases
Optional array of hashtable (or any IDictionary) objects.  If this parameter is used,
Pester will call the test script block once for each table in the TestCases array,
splatting the dictionary to the test script block as input.  If you want the name of
the test to appear differently for each test case, you can embed tokens into the Name
parameter with the syntax 'Adds numbers <A> and <B>' (assuming you have keys named A and B
in your TestCases hashtables.)

.EXAMPLE
function Add-Numbers($a, $b) {
    return $a + $b
}

Describe "Add-Numbers" {
    It "adds positive numbers" {
        $sum = Add-Numbers 2 3
        $sum | Should Be 5
    }

    It "adds negative numbers" {
        $sum = Add-Numbers (-2) (-2)
        $sum | Should Be (-4)
    }

    It "adds one negative number to positive number" {
        $sum = Add-Numbers (-2) 2
        $sum | Should Be 0
    }

    It "concatenates strings if given strings" {
        $sum = Add-Numbers two three
        $sum | Should Be "twothree"
    }
}

.EXAMPLE
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
        $sum | Should Be $expectedResult
    }
}

.LINK
Describe
Context
about_should
#>
    param(
        [Parameter(Mandatory = $true)]
        [string]$name,
        [ScriptBlock] $test = $(Throw "No test script block is provided. (Have you put the open curly brace on the next line?)"),
        [System.Collections.IDictionary[]] $TestCases
    )

    Assert-DescribeInProgress -CommandName It

    if ($null -ne $TestCases -and $TestCases.Count -gt 0)
    {
        foreach ($testCase in $TestCases)
        {
            $expandedName = [regex]::Replace($name, '<([^>]+)>', {
                $capture = $args[0].Groups[1].Value
                if ($testCase.Contains($capture))
                {
                    $testCase[$capture]
                }
                else
                {
                    "<$capture>"
                }
            })

            $splat = @{
                Name = $expandedName
                Scriptblock = $test
                Parameters = $testCase
                ParameterizedSuiteName = $name
                OutputScriptBlock = ${function:Write-PesterResult}
            }

            Invoke-Test @splat
        }
    }
    else
    {
        Invoke-Test -Name $name -ScriptBlock $test -OutputScriptBlock ${function:Write-PesterResult}
    }
}

function Invoke-Test
{
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock,

        [scriptblock] $OutputScriptBlock,

        [System.Collections.IDictionary] $Parameters,
        [string] $ParameterizedSuiteName
    )

    if ($null -eq $Parameters) { $Parameters = @{} }

    $Pester.EnterTest($Name)
    Invoke-SetupBlocks

    $PesterException = $null
    try{
        $null = & $ScriptBlock @Parameters
    } catch {
        $PesterException = $_
    }

    $Result = Get-PesterResult -Test $ScriptBlock -Exception $PesterException
    $Pester.AddTestResult( $Result.name, $Result.Success, $null, $result.FailureMessage, $result.StackTrace, $ParameterizedSuiteName )

    if ($null -ne $OutputScriptBlock)
    {
        $Pester.testresult[-1] | & $OutputScriptBlock
    }

    Invoke-TeardownBlocks
    Exit-MockScope
    $Pester.LeaveTest()
}

function Get-PesterResult {
    param([ScriptBlock] $Test, $Time, $Exception)
    $testResult = @{
        name = $name
        time = $time
        failureMessage = ""
        stackTrace = ""
        success = $false
    };

    if(-not $exception)
    {
        $testResult.success = $true
    }
    else
    {
        if ($exception.FullyQualifiedErrorID -eq 'PesterAssertionFailed')
        {
            $failureMessage = $exception.exception.message
            $file = $test.File
            $line = if ( $exception.ErrorDetails.message -match "\d+$" )  { $matches[0] }
        }
        else {
            $failureMessage = $exception.ToString()
            $file = $Exception.InvocationInfo.ScriptName
            $line = $Exception.InvocationInfo.ScriptLineNumber
        }

        $testResult.failureMessage = $failureMessage -replace "Exception calling", "Assert failed on"
        $testResult.stackTrace = "at line: $line in $file"
    }
    return $testResult
}
