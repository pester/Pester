function Describe {
<#
.SYNOPSIS
Defines the context bounds of a test. One may use this block to 
encapsulate a scenario for testing - a set of conditions assumed
to be present and that should lead to various expected results
represented by the IT blocks.

.PARAMETER Name
The name of the Test. This is often an expressive phsae describing the scenario being tested.

.PARAMETER Fixture
The actual test script. If you are following the AAA pattern (Arrange-Act-Assert), this 
typically holds the arrange and act sections. The Asserts will also lie in this block but are 
typically nested each in its own IT block.

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
It
Context
Invoke-Pester
about_TestDrive

#>

param(

        [Parameter(Mandatory = $true, Position = 0)] $name,

        $tags=@(),

        [Parameter(Mandatory = $true, Position = 1)]
        [ScriptBlock] $fixture
)

    if($testName -ne '' -and $testName.ToLower() -ne $name.ToLower()) {return}
    if($arr_testTags -ne '' -and @(Compare-Object $tags $arr_testTags -IncludeEqual -ExcludeDifferent).count -eq 0) {return}

    Setup

    $results = Get-GlobalTestResults
	$margin = " " * $results.TestDepth
    $results.TestDepth += 1
    $results.CurrentDescribe = @{
        name = $name
        Tests = @()
    }
    

	$output = $margin + "Describing " + $name

    Write-Host -fore yellow $output
    & $fixture
    Cleanup
	$results.Describes += $results.CurrentDescribe
    $results.TestDepth -= 1
}
