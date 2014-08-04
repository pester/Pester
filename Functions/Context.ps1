function Context {
<#
.SYNOPSIS
Provides syntactic sugar for logiclly grouping It blocks within a single Describe block.

.PARAMETER Name
The name of the Context. This is a phrase describing a set of tests within a describe.

.PARAMETER Fixture
Script that is executed. This may include setup specific to the context and one or more It blocks that validate the expected outcomes.

.EXAMPLE
function Add-Numbers($a, $b) {
    return $a + $b
}

Describe "Add-Numbers" {

    Context "when root does not exist" {
         It "..." { ... }
    }

    Context "when root does exist" {
        It "..." { ... }
        It "..." { ... }
        It "..." { ... }
    }
}

.LINK
Describe
It
about_TestDrive

#>
param(
    [Parameter(Mandatory = $true)]
    $name,

    [ValidateNotNull()]
    [ScriptBlock] $fixture = $(Throw "No test script block is provided. (Have you put the open curly brace on the next line?)")
)
    $Pester.EnterContext($name)
    $TestDriveContent = Get-TestDriveChildItem

    $Pester.CurrentContext | Write-Context

    try
    {
        Add-SetupAndTeardown -ScriptBlock $fixture
        $null = & $fixture
    }
    catch
    {
        $firstStackTraceLine = $_.ScriptStackTrace -split '\r?\n' | Select-Object -First 1
        $Pester.AddTestResult('Error occurred in Context block', $false, $null, $_.Exception.Message, $firstStackTraceLine)
        $Pester.TestResult[-1] | Write-PesterResult
    }

    Clear-SetupAndTeardown
    Clear-TestDrive -Exclude ($TestDriveContent | select -ExpandProperty FullName)
    Clear-Mocks
    $Pester.LeaveContext()
}

