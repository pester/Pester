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
    $pester.margin = " " * $pester.results.TestDepth
    $pester.error_margin = $pester.margin * 2
    $pester.results.TestCount += 1

    $pester.output = " $($pester.margin)$name"

    $pester.start_line_position = $test.StartPosition.StartLine
    $pester.test_file = $test.File

    Setup-TestFunction
    . $TestDrive\temp.ps1

    $pester.testResult = @{
        name = $name
        time = 0
        failureMessage = ""
        stackTrace = ""
        success = $false
    };

    $pester.testTime = Measure-Command {
        try{
            temp
            $pester.testResult.success = $true
        } catch {
            $pester.results.FailedTestsCount += 1
            $pester.failure_message = $_.toString() -replace "Exception calling", "Assert failed on"
            $pester.temp_line_number =  $_.InvocationInfo.ScriptLineNumber-2
            $pester.failure_line_number = $pester.start_line_position + $pester.temp_line_number
            $pester.testResult.failureMessage = $pester.failure_message
            $pester.testResult.stackTrace = "at line: $($pester.failure_line_number) in $($pester.test_file)"
        }
    }

    $pester.testResult.time = $pester.testTime.TotalSeconds
    $pester.humanSeconds = Get-HumanTime $pester.testTime.TotalSeconds
    if($pester.testResult.success) {
        "[+] $($pester.output) $($pester.humanSeconds)" | Write-Host -ForegroundColor green;
    }
    else {
        "[-] $($pester.output) $($pester.humanSeconds)" | Write-Host -ForegroundColor red
         Write-Host -ForegroundColor red $($pester.error_margin)$($pester.testResult.failureMessage)
         Write-Host -ForegroundColor red $($pester.error_margin)$($pester.testResult.stackTrace)
    }

    $pester.results.CurrentDescribe.Tests += $pester.testResult;
    $pester.results.TotalTime += $pester.testTime.TotalSeconds;
}

function Setup-TestFunction {
@"
function temp {
$test
}
"@ | out-file $TestDrive\temp.ps1
}
