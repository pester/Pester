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
    $results = Get-GlobalTestResults
    $margin = " " * $results.TestDepth
    $error_margin = $margin * 2
    $results.TestCount += 1

    $output = " $margin$name"

    $start_line_position = $test.StartPosition.StartLine
    $test_file = $test.File

    Setup-TestFunction
    . $TestDrive\temp.ps1

    $testResult = @{
        name = $name
        time = 0
        failureMessage = ""
        stackTrace = ""
        success = $false
    };

    Start-PesterConsoleTranscript

    $testTime = Measure-Command {
        try{
            temp
            $testResult.success = $true
        } catch {
            $failure_message = $_.toString() -replace "Exception calling", "Assert failed on"
            $temp_line_number =  $_.InvocationInfo.ScriptLineNumber - 2
            $failure_line_number = $start_line_position + $temp_line_number
            $results.FailedTestsCount += 1
            $testResult.failureMessage = $failure_message
            $testResult.stackTrace = "at line: $failure_line_number in  $test_file"
        }
    }
    
    $testResult.time = $testTime.TotalSeconds
    $humanSeconds = Get-HumanTime $testTime.TotalSeconds
    if($testResult.success) {
        "[+] $output ($humanSeconds)" | Write-Host -ForegroundColor green;
    }
    else {
        "[-] $output ($humanSeconds)" | Write-Host -ForegroundColor red
         Write-Host -ForegroundColor red $error_margin$($testResult.failureMessage)
         Write-Host -ForegroundColor red $error_margin$($testResult.stackTrace)
    }

    $results.CurrentDescribe.Tests += $testResult;
    $results.TotalTime += $testTime.TotalSeconds;
    Stop-PesterConsoleTranscript
}

function Start-PesterConsoleTranscript {
    if (-not (Test-Path $TestDrive\transcripts)) {
        md $TestDrive\transcripts | Out-Null
    }
    Start-Transcript -Path "$TestDrive\transcripts\console.out" | Out-Null
}

function Stop-PesterConsoleTranscript {
    Stop-Transcript | Out-Null
}

function Get-ConsoleText {
    return (Get-Content "$TestDrive\transcripts\console.out")
}

function Setup-TestFunction {
@"
function temp {
$test
}
"@ | out-file $TestDrive\temp.ps1
}
