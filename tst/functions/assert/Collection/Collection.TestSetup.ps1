Set-StrictMode -Version Latest

if (-not (Get-Command Verify-AssertionFailed -ErrorAction Ignore)) {
    Import-Module (Join-Path $PSScriptRoot '..\..\..\axiom\Axiom.psm1') -DisableNameChecking -ErrorAction Stop
}

if (-not (Get-Command InPesterModuleScope -ErrorAction Ignore)) {
    function InPesterModuleScope {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [scriptblock] $ScriptBlock
        )

        $module = Get-Module -Name Pester -ErrorAction Stop
        . $module $ScriptBlock
    }
}
