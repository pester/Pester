if ($PSVersionTable.PSVersion.Major -ge 3) {
    $script:IgnoreErrorPreference = 'Ignore'
    $outNullModule = 'Microsoft.PowerShell.Core'
    $outHostModule = 'Microsoft.PowerShell.Core'
}
else {
    $script:IgnoreErrorPreference = 'SilentlyContinue'
    $outNullModule = 'Microsoft.PowerShell.Utility'
    $outHostModule = $null
}

# Tried using $ExecutionState.InvokeCommand.GetCmdlet() here, but it does not trigger module auto-loading the way
# Get-Command does.  Since this is at import time, before any mocks have been defined, that's probably acceptable.
# If someone monkeys with Get-Command before they import Pester, they may break something.

# The -All parameter is required when calling Get-Command to ensure that PowerShell can find the command it is
# looking for. Otherwise, if you have modules loaded that define proxy cmdlets or that have cmdlets with the same
# name as the safe cmdlets, Get-Command will return null.
$safeCommandLookupParameters = @{
    CommandType = [System.Management.Automation.CommandTypes]::Cmdlet
    ErrorAction = [System.Management.Automation.ActionPreference]::Stop
}

if ($PSVersionTable.PSVersion.Major -gt 2) {
    $safeCommandLookupParameters['All'] = $true
}

$script:SafeCommands = @{
    'Add-Member'           = Get-Command -Name Add-Member           -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Add-Type'             = Get-Command -Name Add-Type             -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Compare-Object'       = Get-Command -Name Compare-Object       -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Export-ModuleMember'  = Get-Command -Name Export-ModuleMember  -Module Microsoft.PowerShell.Core       @safeCommandLookupParameters
    'ForEach-Object'       = Get-Command -Name ForEach-Object       -Module Microsoft.PowerShell.Core       @safeCommandLookupParameters
    'Format-Table'         = Get-Command -Name Format-Table         -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Get-Alias'            = Get-Command -Name Get-Alias            -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Get-ChildItem'        = Get-Command -Name Get-ChildItem        -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Get-Command'          = Get-Command -Name Get-Command          -Module Microsoft.PowerShell.Core       @safeCommandLookupParameters
    'Get-Content'          = Get-Command -Name Get-Content          -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Get-Date'             = Get-Command -Name Get-Date             -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Get-Item'             = Get-Command -Name Get-Item             -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Get-ItemProperty'     = Get-Command -Name Get-ItemProperty     -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Get-Location'         = Get-Command -Name Get-Location         -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Get-Member'           = Get-Command -Name Get-Member           -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Get-Module'           = Get-Command -Name Get-Module           -Module Microsoft.PowerShell.Core       @safeCommandLookupParameters
    'Get-PSDrive'          = Get-Command -Name Get-PSDrive          -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Get-PSCallStack'      = Get-Command -Name Get-PSCallStack      -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Get-Unique'           = Get-Command -Name Get-Unique           -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Get-Variable'         = Get-Command -Name Get-Variable         -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Group-Object'         = Get-Command -Name Group-Object         -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Import-LocalizedData' = Get-Command -Name Import-LocalizedData -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Import-Module'        = Get-Command -Name Import-Module        -Module Microsoft.PowerShell.Core       @safeCommandLookupParameters
    'Join-Path'            = Get-Command -Name Join-Path            -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Measure-Object'       = Get-Command -Name Measure-Object       -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'New-Item'             = Get-Command -Name New-Item             -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'New-ItemProperty'     = Get-Command -Name New-ItemProperty     -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'New-Module'           = Get-Command -Name New-Module           -Module Microsoft.PowerShell.Core       @safeCommandLookupParameters
    'New-Object'           = Get-Command -Name New-Object           -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'New-PSDrive'          = Get-Command -Name New-PSDrive          -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'New-Variable'         = Get-Command -Name New-Variable         -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Out-Host'             = Get-Command -Name Out-Host             -Module $outHostModule                  @safeCommandLookupParameters
    'Out-File'             = Get-Command -Name Out-File             -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Out-Null'             = Get-Command -Name Out-Null             -Module $outNullModule                  @safeCommandLookupParameters
    'Out-String'           = Get-Command -Name Out-String           -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Pop-Location'         = Get-Command -Name Pop-Location         -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Push-Location'        = Get-Command -Name Push-Location        -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Remove-Item'          = Get-Command -Name Remove-Item          -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Remove-PSBreakpoint'  = Get-Command -Name Remove-PSBreakpoint  -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Remove-PSDrive'       = Get-Command -Name Remove-PSDrive       -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Remove-Variable'      = Get-Command -Name Remove-Variable      -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Resolve-Path'         = Get-Command -Name Resolve-Path         -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Select-Object'        = Get-Command -Name Select-Object        -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Set-Alias'            = Get-Command -Name Set-Alias            -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Set-Content'          = Get-Command -Name Set-Content          -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Set-Location'         = Get-Command -Name Set-Location         -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Set-PSBreakpoint'     = Get-Command -Name Set-PSBreakpoint     -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Set-StrictMode'       = Get-Command -Name Set-StrictMode       -Module Microsoft.PowerShell.Core       @safeCommandLookupParameters
    'Set-Variable'         = Get-Command -Name Set-Variable         -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Sort-Object'          = Get-Command -Name Sort-Object          -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Split-Path'           = Get-Command -Name Split-Path           -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Start-Sleep'          = Get-Command -Name Start-Sleep          -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Test-Path'            = Get-Command -Name Test-Path            -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
    'Where-Object'         = Get-Command -Name Where-Object         -Module Microsoft.PowerShell.Core       @safeCommandLookupParameters
    'Write-Error'          = Get-Command -Name Write-Error          -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Write-Host'           = Get-Command -Name Write-Host           -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Write-Progress'       = Get-Command -Name Write-Progress       -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Write-Verbose'        = Get-Command -Name Write-Verbose        -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
    'Write-Warning'        = Get-Command -Name Write-Warning        -Module Microsoft.PowerShell.Utility    @safeCommandLookupParameters
}

# Not all platforms have Get-WmiObject (Nano or PSCore 6.0.0-beta.x on Linux)
# Get-CimInstance is preferred, but we can use Get-WmiObject if it exists
# Moreover, it shouldn't really be fatal if neither of those cmdlets
# exist
if ( Get-Command -ea SilentlyContinue Get-CimInstance ) {
    $script:SafeCommands['Get-CimInstance'] = Get-Command -Name Get-CimInstance -Module CimCmdlets @safeCommandLookupParameters
}
elseif ( Get-command -ea SilentlyContinue Get-WmiObject ) {
    $script:SafeCommands['Get-WmiObject'] = Get-Command -Name Get-WmiObject   -Module Microsoft.PowerShell.Management @safeCommandLookupParameters
}
elseif ( Get-Command -ea SilentlyContinue uname -Type Application ) {
    $script:SafeCommands['uname'] = Get-Command -Name uname -Type Application | Select-Object -First 1
    if ( Get-Command -ea SilentlyContinue id -Type Application ) {
        $script:SafeCommands['id'] = Get-Command -Name id -Type Application | Select-Object -First 1
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

