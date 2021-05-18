function Discover-Test {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSObject[]] $BlockContainer,
        [Parameter(Mandatory = $true)]
        [Management.Automation.SessionState] $SessionState,
        $Filter
    )
    $totalDiscoveryDuration = [Diagnostics.Stopwatch]::StartNew()

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Discovery -Message "Starting test discovery in $(@($BlockContainer).Length) test containers."
    }

    $steps = $state.Plugin.DiscoveryStart
    if ($null -ne $steps -and 0 -lt @($steps).Count) {
        Invoke-PluginStep -Plugins $state.Plugin -Step DiscoveryStart -Context @{
            BlockContainers = $BlockContainer
            Configuration   = $state.PluginConfiguration
            Filter          = $Filter
        } -ThrowOnFailure
    }

    $state.Discovery = $true
    $found = foreach ($container in $BlockContainer) {
        $perContainerDiscoveryDuration = [Diagnostics.Stopwatch]::StartNew()

        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Discovery "Discovering tests in $($container.Item)"
        }

        # this is a block object that we add so we can capture
        # OneTime* and Each* setups, and capture multiple blocks in a
        # container
        $root = [Pester.Block]::Create()
        $root.ExpandedName = $root.Name = "Root"

        $root.IsRoot = $true
        $root.ExpandedPath = $root.Path = "Path"

        $root.First = $true
        $root.Last = $true

        # set the data from the container to get them
        # set correctly as if we provided -Data to New-Block
        $root.Data = $container.Data

        Reset-PerContainerState -RootBlock $root

        $steps = $state.Plugin.ContainerDiscoveryStart
        if ($null -ne $steps -and 0 -lt @($steps).Count) {
            Invoke-PluginStep -Plugins $state.Plugin -Step ContainerDiscoveryStart -Context @{
                BlockContainer = $container
                Configuration  = $state.PluginConfiguration
            } -ThrowOnFailure
        }

        try {
            $null = Invoke-BlockContainer -BlockContainer $container -SessionState $SessionState
        }
        catch {
            $root.Passed = $false
            $root.Result = "Failed"
            $root.ErrorRecord.Add($_)
        }

        [PSCustomObject] @{
            Container = $container
            Block     = $root
        }

        $steps = $state.Plugin.ContainerDiscoveryEnd
        if ($null -ne $steps -and 0 -lt @($steps).Count) {
            Invoke-PluginStep -Plugins $state.Plugin -Step ContainerDiscoveryEnd -Context @{
                BlockContainer = $container
                Block          = $root
                Duration       = $perContainerDiscoveryDuration.Elapsed
                Configuration  = $state.PluginConfiguration
            } -ThrowOnFailure
        }

        $root.DiscoveryDuration = $perContainerDiscoveryDuration.Elapsed
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Discovery -LazyMessage { "Found $(@(View-Flat -Block $root).Count) tests in $([int]$root.DiscoveryDuration.TotalMilliseconds) ms" }
            Write-PesterDebugMessage -Scope DiscoveryCore "Discovery done in this container."
        }
    }

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Discovery "Processing discovery result objects, to set root, parents, filters etc."
    }

    # focusing is removed from the public api
    # # if any tests / block in the suite have -Focus parameter then all filters are disregarded
    # # and only those tests / blocks should run
    # $focusedTests = [System.Collections.Generic.List[Object]]@()
    # foreach ($f in $found) {
    #     Fold-Container -Container $f.Block `
    #         -OnTest {
    #             # add all focused tests
    #             param($t)
    #             if ($t.Focus) {
    #                 $focusedTests.Add("$(if($null -ne $t.ScriptBlock.File) { $t.ScriptBlock.File } else { $t.ScriptBlock.Id }):$($t.ScriptBlock.StartPosition.StartLine)")
    #             }
    #         } `
    #         -OnBlock {
    #             param($b) if ($b.Focus) {
    #                 # add all tests in the current block, no matter if they are focused or not
    #                 Fold-Block -Block $b -OnTest {
    #                     param ($t)
    #                     $focusedTests.Add("$(if($null -ne $t.ScriptBlock.File) { $t.ScriptBlock.File } else { $t.ScriptBlock.Id }):$($t.ScriptBlock.StartPosition.StartLine)")
    #                 }
    #             }
    #         }
    # }

    # if ($focusedTests.Count -gt 0) {
    #     if ($PesterPreference.Debug.WriteDebugMessages.Value) {
    #         Write-PesterDebugMessage -Scope Discovery  -LazyMessage { "There are some ($($focusedTests.Count)) focused tests '$($(foreach ($p in $focusedTests) { $p -join "." }) -join ",")' running just them." }
    #     }
    #     $Filter =  New-FilterObject -Line $focusedTests
    # }

    foreach ($f in $found) {
        # this takes non-trivial time, measure how long it takes and add it to the discovery
        # so we get more accurate total time
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        PostProcess-DiscoveredBlock -Block $f.Block -Filter $Filter -BlockContainer $f.Container -RootBlock $f.Block
        $overhead = $sw.Elapsed
        $f.Block.DiscoveryDuration += $overhead
        # Write-Host "disc $($f.Block.DiscoveryDuration.totalmilliseconds) $($overhead.totalmilliseconds) ms" #TODO
        $f.Block
    }

    $steps = $state.Plugin.DiscoveryEnd
    if ($null -ne $steps -and 0 -lt @($steps).Count) {
        Invoke-PluginStep -Plugins $state.Plugin -Step DiscoveryEnd -Context @{
            BlockContainers = $found.Block
            AnyFocusedTests = $focusedTests.Count -gt 0
            FocusedTests    = $focusedTests
            Duration        = $totalDiscoveryDuration.Elapsed
            Configuration   = $state.PluginConfiguration
        } -ThrowOnFailure
    }

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Discovery "Test discovery finished."
    }
}
