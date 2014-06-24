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

    try
    {
        $Pester.SessionState = $module.SessionState
        
        # Avoid modifying the ScriptBlock instance that was passed in, just in case this causes unexpected problems

        $_scriptBlock = [scriptblock]::Create($ScriptBlock.ToString())
        Set-ScriptBlockScope -ScriptBlock $_scriptBlock -SessionState $module.SessionState

        & $_scriptBlock
    }
    finally
    {
        $Pester.SessionState = $originalState
    }
}