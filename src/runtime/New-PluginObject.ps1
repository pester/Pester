function New-PluginObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String] $Name,
        [Hashtable] $Configuration,
        [ScriptBlock] $Start,
        [ScriptBlock] $DiscoveryStart,
        [ScriptBlock] $ContainerDiscoveryStart,
        [ScriptBlock] $BlockDiscoveryStart,
        [ScriptBlock] $TestDiscoveryStart,
        [ScriptBlock] $TestDiscoveryEnd,
        [ScriptBlock] $BlockDiscoveryEnd,
        [ScriptBlock] $ContainerDiscoveryEnd,
        [ScriptBlock] $DiscoveryEnd,
        [ScriptBlock] $RunStart,
        [scriptblock] $ContainerRunStart,
        [ScriptBlock] $OneTimeBlockSetupStart,
        [ScriptBlock] $EachBlockSetupStart,
        [ScriptBlock] $OneTimeTestSetupStart,
        [ScriptBlock] $EachTestSetupStart,
        [ScriptBlock] $EachTestTeardownEnd,
        [ScriptBlock] $OneTimeTestTeardownEnd,
        [ScriptBlock] $EachBlockTeardownEnd,
        [ScriptBlock] $OneTimeBlockTeardownEnd,
        [ScriptBlock] $ContainerRunEnd,
        [ScriptBlock] $RunEnd,
        [ScriptBlock] $End
    )

    [PSCustomObject] @{
        Name                    = $Name
        Configuration           = $Configuration
        Start                   = $Start
        DiscoveryStart          = $DiscoveryStart
        ContainerDiscoveryStart = $ContainerDiscoveryStart
        BlockDiscoveryStart     = $BlockDiscoveryStart
        TestDiscoveryStart      = $TestDiscoveryStart
        TestDiscoveryEnd        = $TestDiscoveryEnd
        BlockDiscoveryEnd       = $BlockDiscoveryEnd
        ContainerDiscoveryEnd   = $ContainerDiscoveryEnd
        DiscoveryEnd            = $DiscoveryEnd
        RunStart                = $RunStart
        ContainerRunStart       = $ContainerRunStart
        OneTimeBlockSetupStart  = $OneTimeBlockSetupStart
        EachBlockSetupStart     = $EachBlockSetupStart
        OneTimeTestSetupStart   = $OneTimeTestSetupStart
        EachTestSetupStart      = $EachTestSetupStart
        EachTestTeardownEnd     = $EachTestTeardownEnd
        OneTimeTestTeardownEnd  = $OneTimeTestTeardownEnd
        EachBlockTeardownEnd    = $EachBlockTeardownEnd
        OneTimeBlockTeardownEnd = $OneTimeBlockTeardownEnd
        ContainerRunEnd         = $ContainerRunEnd
        RunEnd                  = $RunEnd
        End                     = $End
        PSTypeName              = 'Plugin'
    }
}
