function Context {
<#
.SYNOPSIS
Provides syntactic sugar for logiclly grouping It blocks within a single Describe block.

.PARAMETER Name
The name of the Context. This is a phsae describing a set of tests within a describe.

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

#>
param(
    $name, 
    [ScriptBlock] $fixture
)

    Setup

    $results = Get-GlobalTestResults
	$margin = " " * $results.TestDepth
    $results.TestDepth += 1

	Write-Host -fore yellow $margin $name
    & $fixture

    Cleanup

	$results.TestDepth -= 1
}

