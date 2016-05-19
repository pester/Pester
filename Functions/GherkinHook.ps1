function Hook {
    [CmdletBinding(DefaultParameterSetName="All")]
    param(
        [Parameter(Mandatory=$True, Position=0, ParameterSetName="Tags")]
        [String[]]$Tags = @(),

        [Parameter(Mandatory=$True, Position=1, ParameterSetName="Tags")]
        [Parameter(Mandatory=$True, Position=0, ParameterSetName="All")]
        [ScriptBlock]$Script
    )
    $Name = $MyInvocation.InvocationName

    $Script:GherkinHooks.${Name} += @( @{ Tags = $Tags; Script = $Script } )
}

Set-Alias BeforeAllFeatures Hook
Set-Alias BeforeFeature Hook
Set-Alias BeforeScenario Hook
Set-Alias BeforeStep Hook

Set-Alias AfterAllFeatures Hook
Set-Alias AfterFeature Hook
Set-Alias AfterScenario Hook
Set-Alias AfterStep Hook
