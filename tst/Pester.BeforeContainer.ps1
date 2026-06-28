# Per-container initialization for the Pester self-tests. When this file sits in the repository
# root (Run.RepoRoot), Pester dot-sources it before each test file is discovered and run - in both
# sequential and parallel runs, and inside every worker runspace when running in parallel. The
# self-tests rely on the TestHelpers module and the Axiom assertion module that test.ps1 normally
# imports into the session, so we re-create them here. This file lives under tst/, so it is picked
# up when Run.RepoRoot points at tst (e.g. when running the self-tests in parallel).

Import-Module $PSScriptRoot/axiom/Axiom.psm1 -DisableNameChecking

Get-Module TestHelpers | Remove-Module

New-Module -Name TestHelpers -ScriptBlock {
    function InPesterModuleScope {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [scriptblock]
            $ScriptBlock
        )

        $module = Get-Module -Name Pester -ErrorAction Stop
        . $module $ScriptBlock
    }

    function New-Dictionary ([hashtable]$Hashtable) {
        $d = [System.Collections.Generic.Dictionary[string, object]]::new()
        $Hashtable.GetEnumerator() | ForEach-Object { $d.Add($_.Key, $_.Value) }

        $d
    }

    function Clear-WhiteSpace ($Text) {
        "$($Text -replace "(`t|`n|`r)"," " -replace "\s+"," ")".Trim()
    }
} | Out-Null
