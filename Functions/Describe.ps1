function Describe {
<#
.SYNOPSIS
Creates a logical group of tests.  All Mocks and TestDrive contents
defined within a Describe block are scoped to that Describe; they
will no longer be present when the Describe block exits.  A Describe
block may contain any number of Context and It blocks.

.PARAMETER Name
The name of the test group. This is often an expressive phrase describing the scenario being tested.

.PARAMETER Fixture
The actual test script. If you are following the AAA pattern (Arrange-Act-Assert), this
typically holds the arrange and act sections. The Asserts will also lie in this block but are
typically nested each in its own It block. Assertions are typically performed by the Should
command within the It blocks.

.PARAMETER Tags
Optional parameter containing an array of strings.  When calling Invoke-Pester, it is possible to
specify a -Tag parameter which will only execute Describe blocks containing the same Tag.

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

.LINK
It
Context
Invoke-Pester
about_Should
about_Mocking
about_TestDrive

#>

    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Name,
        $Tags=@(),
        [Parameter(Position = 1)]
        [ValidateNotNull()]
        [ScriptBlock] $Fixture = $(Throw "No test script block is provided. (Have you put the open curly brace on the next line?)")
    )

    if ($null -eq (Get-Variable -Name Pester -ValueOnly -ErrorAction $script:IgnoreErrorPreference))
    {
        # User has executed a test script directly instead of calling Invoke-Pester
        $Pester = New-PesterState -Path (Resolve-Path .) -TestNameFilter $null -TagFilter @() -SessionState $PSCmdlet.SessionState
        $script:mockTable = @{}
    }

    if($Pester.TestNameFilter-and -not ($Pester.TestNameFilter | Where-Object { $Name -like $_ }))
    {
        #skip this test
        return
    }

    #TODO add test to test tags functionality
    if($Pester.TagFilter -and @(Compare-Object $Tags $Pester.TagFilter -IncludeEqual -ExcludeDifferent).count -eq 0) {return}
    if($Pester.ExcludeTagFilter -and @(Compare-Object $Tags $Pester.ExcludeTagFilter -IncludeEqual -ExcludeDifferent).count -gt 0) {return}

    $Pester.EnterDescribe($Name)

    $Pester.CurrentDescribe | Write-Describe
    $testDriveAdded = $false

    try
    {
        New-TestDrive
        $testDriveAdded = $true

        Add-SetupAndTeardown -ScriptBlock $Fixture
        Invoke-TestGroupSetupBlocks -Scope $pester.Scope

        do
        {
            $null = & $Fixture
        } until ($true)
    }
    catch
    {
        $firstStackTraceLine = $_.InvocationInfo.PositionMessage.Trim() -split '\r?\n' | Select-Object -First 1
        $Pester.AddTestResult('Error occurred in Describe block', "Failed", $null, $_.Exception.Message, $firstStackTraceLine)
        $Pester.TestResult[-1] | Write-PesterResult
    }
    finally
    {
        Invoke-TestGroupTeardownBlocks -Scope $pester.Scope
        if ($testDriveAdded) { Remove-TestDrive }
    }

    Clear-SetupAndTeardown
    Exit-MockScope
    $Pester.LeaveDescribe()
}

function Assert-DescribeInProgress
{
    param ($CommandName)
    if ($null -eq $Pester -or [string]::IsNullOrEmpty($Pester.CurrentDescribe))
    {
        throw "The $CommandName command may only be used inside a Describe block."
    }
}
