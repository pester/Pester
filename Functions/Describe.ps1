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
        [Parameter(Position = 1)]
        [ValidateNotNull()]
        [ScriptBlock] $fixture = $(Throw "No test script block is provided. (Have you put the open curly brace on the next line?)")
)

    if ($null -eq (Get-Variable -Name Pester -ValueOnly -ErrorAction SilentlyContinue))
    {
        # User has executed a test script directly instead of calling Invoke-Pester
        $Pester = New-PesterState -Path (Resolve-Path .) -TestNameFilter $null -TagFilter @() -SessionState $PSCmdlet.SessionState
        $script:mockTable = @{}
    }

    if($Pester.TestNameFilter -and ($Name -notlike $Pester.TestNameFilter))
    {
        #skip this test
        return
    }

    #TODO add test to test tags functionality
    if($pester.TagFilter -and @(Compare-Object $tags $pester.TagFilter -IncludeEqual -ExcludeDifferent).count -eq 0) {return}

    $Pester.EnterDescribe($Name)
    $Pester.CurrentDescribe | Write-Describe
    New-TestDrive

    try
    {
        Add-SetupAndTeardown -ScriptBlock $fixture
        $null = & $fixture
    }
    catch
    {
        $firstStackTraceLine = $_.InvocationInfo.PositionMessage.Trim() -split '\r?\n' | Select-Object -First 1
        $Pester.AddTestResult('Error occurred in Describe block', $false, $null, $_.Exception.Message, $firstStackTraceLine)
        $Pester.TestResult[-1] | Write-PesterResult
    }

    Clear-SetupAndTeardown
    Remove-TestDrive
    Exit-MockScope
    $Pester.LeaveDescribe()
}

function Assert-DescribeInProgress
{
    param ($CommandName)
    if ($null -eq $pester -or [string]::IsNullOrEmpty($pester.CurrentDescribe))
    {
        throw "The $CommandName command may only be used inside a Describe block."
    }
}
