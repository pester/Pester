function It {
<#
.SYNOPSIS
Validates the results of a test inside of a Describe block.

.DESCRIPTION
The It function is intended to be used inside of a Describe 
Block. If you are familiar with the AAA pattern 
(Arrange-Act-Assert), this would be the appropriate location 
for an assert. The convention is to assert a single 
expectation for each It block. The code inside of the It block 
should throw an exception if the expectation of the test is not 
met and thus cause the test to fail. The name of the It block 
should expressively state the expectation of the test.

In addition to using your own logic to test expectations and 
throw exceptions, you may also use Pester's own helper functions 
to assist in evaluating test results using the Should object. 

.PARAMETER Name
An expressive phsae describing the expected test outcome.

.PARAMETER Test
The script block that should throw an exception if the 
expectation of the test is not met.If you are following the 
AAA pattern (Arrange-Act-Assert), this typically holds the 
Assert. 

.EXAMPLE
function Add-Numbers($a, $b) {
    return $a + $b
}

Describe "Add-Numbers" {

    It "adds positive numbers" {
        $sum = Add-Numbers 2 3
        $sum.should.be(5)
    }

    It "adds negative numbers" {
        $sum = Add-Numbers (-2) (-2)
        $sum.should.be((-4))
    }

    It "adds one negative number to positive number" {
        $sum = Add-Numbers (-2) 2
        $sum.should.be(0)
    }

    It "concatenates strings if given strings" {
        $sum = Add-Numbers two three
        $sum.should.be("twothree")
    }

}

.LINK
Describe
Context
about_should
#>
param(
    $name, 
    [ScriptBlock] $test = $(Throw "No test script block is provided. (Have you put the open curly brace on the next line?)")
)

    $PesterException = $null
    
    $Time = Measure-Command {
        try{
           &{ &$test }
        } catch {
            $PesterException = $_
        }
    }

    $Result = Get-PesterResult -Test $Test -Time $time -Exception $PesterException
    $Pester.AddTestResult($Result.name, $Result.Success, $result.time, $result.failuremessage, $result.StackTrace ) 
    $Pester.testresult[-1] | Write-PesterResult
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
            $line = if ( $exception.ErrorDetails.message -match "\d+$" )  { $matches[0] }
        }
        else {
            $failureMessage = $exception.ToString()
            $line= $exception.InvocationInfo.ScriptLineNumber
        }
        
        $testResult.failureMessage = $failureMessage -replace "Exception calling", "Assert failed on"
        $testResult.stackTrace = "at line: $line in $($test.File)"
    }
    return $testResult
}
