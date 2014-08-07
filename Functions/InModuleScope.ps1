function InModuleScope
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ModuleName,

        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock
    )

    if ($null -eq (Get-Variable -Name Pester -ValueOnly -ErrorAction SilentlyContinue))
    {
        # User has executed a test script directly instead of calling Invoke-Pester
        $Pester = New-PesterState -Path (Resolve-Path .) -TestNameFilter $null -TagFilter @() -SessionState $PSCmdlet.SessionState
        $script:mockTable = @{}
    }

    try
    {
        $module = Get-Module -Name $ModuleName -All -ErrorAction Stop
    }
    catch
    {
        throw "No module named '$ModuleName' is currently loaded."
    }

    $originalState = $Pester.SessionState
    $originalScriptBlockScope = Get-ScriptBlockScope -ScriptBlock $ScriptBlock

    try
    {
        $Pester.SessionState = $module.SessionState

        Set-ScriptBlockScope -ScriptBlock $ScriptBlock -SessionState $module.SessionState

        & $ScriptBlock
    }
    finally
    {
        $Pester.SessionState = $originalState
        Set-ScriptBlockScope -ScriptBlock $ScriptBlock -SessionStateInternal $originalScriptBlockScope 
    }
}
