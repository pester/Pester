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
    [ScriptBlock] $test
)
    $pester.results = Get-GlobalTestResults
    $pester.results.TestCount += 1

    Setup-TestFunction
    . $TestDrive\temp.ps1

    $pester.testTime = Measure-Command {
        try{
            temp
        } catch {
            $pester.results.FailedTestsCount += 1
            $exception = $_
        }
    }

    $pester.testResult = Get-PesterResult $test $exception
    $pester.results.CurrentDescribe.Tests += $pester.testResult
    $pester.results.TotalTime += $pester.testTime.TotalSeconds
    Write-PesterResult
}

function Setup-TestFunction {
@"
function temp {
$test
}
"@ | out-file $TestDrive\temp.ps1
}

function write-PesterResult{
    $pester.margin = " " * $pester.results.TestDepth
    $pester.error_margin = $pester.margin * 2
    $pester.output = " $($pester.margin)$name"
    $pester.humanSeconds = Get-HumanTime $pester.testTime.TotalSeconds
    if($pester.testResult.success) {
        "[+] $($pester.output) $($pester.humanSeconds)" | Write-Host -ForegroundColor green;
    }
    else {
        "[-] $($pester.output) $($pester.humanSeconds)" | Write-Host -ForegroundColor red
         Write-Host -ForegroundColor red $($pester.error_margin)$($pester.testResult.failureMessage)
         Write-Host -ForegroundColor red $($pester.error_margin)$($pester.testResult.stackTrace)
    }
}

function Get-PesterResult{
    param([ScriptBlock] $test, $exception)
    $testResult = @{
        name = $name
        time = 0
        failureMessage = ""
        stackTrace = ""
        success = $false
    };

    if(!$exception){$testResult.success = $true}
    else {
        $testResult.failureMessage = $Exception.toString() -replace "Exception calling", "Assert failed on"
        if($pester.ShouldExceptionLine) {
            $line=$pester.ShouldExceptionLine
            $pester.ShouldExceptionLine=$null
        }
        else {
            $line=$exception.InvocationInfo.ScriptLineNumber
        }
        $failureLine = $test.StartPosition.StartLine + ($line-2)
        $testResult.stackTrace = "at line: $failureLine in $($test.File)"
    }
    return $testResult
}
