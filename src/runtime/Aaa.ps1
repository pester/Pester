# PESTER_BUILD
if (-not (Get-Variable -Name "PESTER_BUILD" -ValueOnly -ErrorAction Ignore)) {
    . "$PSScriptRoot/../Pester.Utility.ps1"
    . "$PSScriptRoot/../functions/Pester.SafeCommands.ps1"
    . "$PSScriptRoot/../Pester.Types.ps1"

    if ($null -eq $PesterPreference) {
        $PesterPreference = [PesterConfiguration]::Default
    }
}
else {
    if ($null -eq $PesterPreference) {
        $PesterPreference = [PesterConfiguration]::Default
    }
}
# end PESTER_BUILD

# interesting commands
# # the core stuff I am mostly sure about
# 'New-PesterState'
# 'New-Block'
# 'New-ParametrizedBlock'
# 'New-Test'
# 'New-ParametrizedTest'
# 'New-EachTestSetup'
# 'New-EachTestTeardown'
# 'New-OneTimeTestSetup'
# 'New-OneTimeTestTeardown'
# 'New-EachBlockSetup'
# 'New-EachBlockTeardown'
# 'New-OneTimeBlockSetup'
# 'New-OneTimeBlockTeardown'
# 'Add-FrameworkDependency'
# 'Anywhere'
# 'Invoke-Test',
# 'Find-Test',
# 'Invoke-PluginStep'

# # here I have doubts if that is too much to expose
# 'Get-CurrentTest'
# 'Get-CurrentBlock'
# 'Recurse-Up',
# 'Is-Discovery'

# # those are quickly implemented to be useful for demo
# 'Where-Failed'
# 'View-Flat'

# # those need to be refined and probably wrapped to something
# # that is like an object builder
# 'New-FilterObject'
# 'New-PluginObject'
# 'New-BlockContainerObject'


# instances
$flags = [System.Reflection.BindingFlags]'Instance,NonPublic'
$script:SessionStateInternalProperty = [System.Management.Automation.SessionState].GetProperty('Internal', $flags)
$script:ScriptBlockSessionStateInternalProperty = [System.Management.Automation.ScriptBlock].GetProperty('SessionStateInternal', $flags)
$script:ScriptBlockSessionStateProperty = [System.Management.Automation.ScriptBlock].GetProperty("SessionState", $flags)

if (notDefined PesterPreference) {
    $PesterPreference = [PesterConfiguration]::Default
}
else {
    $PesterPreference = [PesterConfiguration] $PesterPreference
}
