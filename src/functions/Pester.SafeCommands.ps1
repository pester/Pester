# Tried using $ExecutionState.InvokeCommand.GetCmdlet() here, but it does not trigger module auto-loading the way
# Get-Command does.  Since this is at import time, before any mocks have been defined, that's probably acceptable.
# If someone monkeys with Get-Command before they import Pester, they may break something.

# The -All parameter is required when calling Get-Command to ensure that PowerShell can find the command it is
# looking for. Otherwise, if you have modules loaded that define proxy cmdlets or that have cmdlets with the same
# name as the safe cmdlets, Get-Command will return null.
$safeCommandLookupParameters = @{
    CommandType = 'Cmdlet'
    ErrorAction = 'Stop'
    All         = $true
}

# Suppress from ScriptAnalyzer rule when possible in root of script (future PSSA release?)
# [Diagnostics.CodeAnalysis.SuppressMessageAttribute('Pester.BuildAnalyzerRules\Measure-SafeCommands', 'Get-Command', Justification = 'Used to generate SafeCommands list used for AnalyzerRule.')]
$Get_Command = Get-Command Get-Command -CommandType Cmdlet -ErrorAction 'Stop'
$script:SafeCommands = @{
    'Get-Command'          = $Get_Command
    'Add-Member'           = & $Get_Command -Name Add-Member           -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Add-Type'             = & $Get_Command -Name Add-Type             -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Compare-Object'       = & $Get_Command -Name Compare-Object       -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Export-ModuleMember'  = & $Get_Command -Name Export-ModuleMember  -Module Microsoft.PowerShell.Core       @safeCommandLookupParameters
    'ForEach-Object'       = & $Get_Command -Name ForEach-Object       -Module Microsoft.PowerShell.Core       @safeCommandLookupParameters
    'Format-Table'         = & $Get_Command -Name Format-Table         -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Get-Alias'            = & $Get_Command -Name Get-Alias            -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Get-ChildItem'        = & $Get_Command -Name Get-ChildItem        -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Get-Content'          = & $Get_Command -Name Get-Content          -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Get-Date'             = & $Get_Command -Name Get-Date             -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Get-Item'             = & $Get_Command -Name Get-Item             -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Get-ItemProperty'     = & $Get_Command -Name Get-ItemProperty     -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Get-Location'         = & $Get_Command -Name Get-Location         -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Get-Member'           = & $Get_Command -Name Get-Member           -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Get-Module'           = & $Get_Command -Name Get-Module           -Module Microsoft.PowerShell.Core       @safeCommandLookupParameters
    'Get-PSDrive'          = & $Get_Command -Name Get-PSDrive          -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Get-PSCallStack'      = & $Get_Command -Name Get-PSCallStack      -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Get-Unique'           = & $Get_Command -Name Get-Unique           -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Get-Variable'         = & $Get_Command -Name Get-Variable         -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Group-Object'         = & $Get_Command -Name Group-Object         -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Import-LocalizedData' = & $Get_Command -Name Import-LocalizedData -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Import-Module'        = & $Get_Command -Name Import-Module        -Module Microsoft.PowerShell.Core       @safeCommandLookupParameters
    'Join-Path'            = & $Get_Command -Name Join-Path            -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Measure-Object'       = & $Get_Command -Name Measure-Object       -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'New-Item'             = & $Get_Command -Name New-Item             -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'New-ItemProperty'     = & $Get_Command -Name New-ItemProperty     -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'New-Module'           = & $Get_Command -Name New-Module           -Module Microsoft.PowerShell.Core       @safeCommandLookupParameters
    'New-Object'           = & $Get_Command -Name New-Object           -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'New-PSDrive'          = & $Get_Command -Name New-PSDrive          -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'New-Variable'         = & $Get_Command -Name New-Variable         -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Out-Host'             = & $Get_Command -Name Out-Host             -Module Microsoft.PowerShell.Core       @safeCommandLookupParameters
    'Out-File'             = & $Get_Command -Name Out-File             -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Out-Null'             = & $Get_Command -Name Out-Null             -Module Microsoft.PowerShell.Core       @safeCommandLookupParameters
    'Out-String'           = & $Get_Command -Name Out-String           -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Pop-Location'         = & $Get_Command -Name Pop-Location         -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Push-Location'        = & $Get_Command -Name Push-Location        -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Remove-Item'          = & $Get_Command -Name Remove-Item          -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Remove-PSBreakpoint'  = & $Get_Command -Name Remove-PSBreakpoint  -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Remove-PSDrive'       = & $Get_Command -Name Remove-PSDrive       -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Remove-Variable'      = & $Get_Command -Name Remove-Variable      -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Resolve-Path'         = & $Get_Command -Name Resolve-Path         -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Select-Object'        = & $Get_Command -Name Select-Object        -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Set-Alias'            = & $Get_Command -Name Set-Alias            -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Set-Content'          = & $Get_Command -Name Set-Content          -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Set-Location'         = & $Get_Command -Name Set-Location         -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Set-PSBreakpoint'     = & $Get_Command -Name Set-PSBreakpoint     -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Set-StrictMode'       = & $Get_Command -Name Set-StrictMode       -Module Microsoft.PowerShell.Core       @safeCommandLookupParameters
    'Set-Variable'         = & $Get_Command -Name Set-Variable         -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Sort-Object'          = & $Get_Command -Name Sort-Object          -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Split-Path'           = & $Get_Command -Name Split-Path           -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Start-Sleep'          = & $Get_Command -Name Start-Sleep          -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Test-Path'            = & $Get_Command -Name Test-Path            -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Where-Object'         = & $Get_Command -Name Where-Object         -Module Microsoft.PowerShell.Core       @safeCommandLookupParameters
    'Write-Error'          = & $Get_Command -Name Write-Error          -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Write-Host'           = & $Get_Command -Name Write-Host           -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Write-Progress'       = & $Get_Command -Name Write-Progress       -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Write-Verbose'        = & $Get_Command -Name Write-Verbose        -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Write-Warning'        = & $Get_Command -Name Write-Warning        -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
}

# Not all platforms have Get-WmiObject (Nano or PSCore 6.0.0-beta.x on Linux)
# Get-CimInstance is preferred, but we can use Get-WmiObject if it exists
# Moreover, it shouldn't really be fatal if neither of those cmdlets
# exist
if (($cim = & $Get_Command -Name Get-CimInstance -Module CimCmdlets -CommandType Cmdlet -ErrorAction Ignore)) {
    $script:SafeCommands['Get-CimInstance'] = $cim
}
elseif (($wmi = & $Get_Command -Name Get-WmiObject -Module Microsoft.PowerShell.Management -CommandType Cmdlet -ErrorAction Ignore)) {
    $script:SafeCommands['Get-WmiObject'] = $wmi
}
elseif (($unames = & $Get_Command -Name uname -CommandType Application -ErrorAction Ignore)) {
    $script:SafeCommands['uname'] = if ($null -ne $unames -and 0 -lt @($unames).Count) { $unames[0] }
    if  (($ids = & $Get_Command -Name id -CommandType Application -ErrorAction Ignore)) {
        $script:SafeCommands['id'] = if ($null -ne $ids -and 0 -lt @($ids).Count) { $ids[0] }
    }
}
else {
    Write-Warning "OS Information retrieval is not possible, reports will contain only partial system data"
}

# little sanity check to make sure we don't blow up a system with a typo up there
# (not that I've EVER done that by, for example, mapping New-Item to Remove-Item...)

foreach ($keyValuePair in $script:SafeCommands.GetEnumerator()) {
    if ($keyValuePair.Key -ne $keyValuePair.Value.Name) {
        throw "SafeCommands entry for $($keyValuePair.Key) does not hold a reference to the proper command."
    }
}

