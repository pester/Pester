# Per-container initialization for Run.Parallel. Pester walks up from each test file and
# dot-sources the first Pester.BeforeContainer.ps1 it finds inside every worker runspace,
# before the file is discovered and run. The Pester self-tests rely on the TestHelpers module
# and the Axiom assertion module that test.ps1 normally imports into the session, so we re-create
# them here for the workers.

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
