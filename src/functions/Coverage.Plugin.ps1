﻿function Get-CoveragePlugin {
    New-PluginObject -Name "Coverage" -RunStart {
        param($Context)

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $logger = if ($Context.WriteDebugMessages) {
            # return partially apply callback to the logger when the logging is enabled
            # or implicit null
            {
                param ($Message)
                & $Context.Write_PesterDebugMessage -Scope CodeCoverage -Message $Message
            }
        }

        if ($null -ne $logger) {
            & $logger "Starting code coverage."
        }

        if ($PesterPreference.Output.Verbosity.Value -ne "None") {
            & $SafeCommands["Write-Host"] -ForegroundColor Magenta "Starting code coverage."
        }

        $config = $Context.Configuration['Coverage']

        if ($null -ne $logger) {
            & $logger "Config: $($config | & $script:SafeCommands['Out-String'])"
        }

        $breakpoints = Enter-CoverageAnalysis -CodeCoverage $config -Logger $logger -UseBreakpoints $config.UseBreakpoints -UseSingleHitBreakpoints $config.UseSingleHitBreakpoints

        if (-not $config.UseBreakpoints) {
            $tracer = Start-TraceScript $breakpoints
        }

        $Context.Data.Add('Coverage', @{
                CommandCoverage = $breakpoints
                Tracer          = $tracer
                CoverageReport  = $null
            })

        if ($PesterPreference.Output.Verbosity.Value -in "Detailed", "Diagnostic") {
            & $SafeCommands["Write-Host"] -ForegroundColor Magenta "Code Coverage preparation finished after $($sw.ElapsedMilliseconds) ms."
        }
    } -End {
        param($Context)

        $config = $Context.Configuration['Coverage']
        if (-not $config.UseBreakpoints) {
            Stop-TraceScript
        }
        if (-not $Context.TestRun.PluginData.ContainsKey("Coverage")) {
            return
        }

        $coverageData = $Context.TestRun.PluginData.Coverage
        #TODO: rather check the config to see which mode of coverage we used
        if ($null -eq $coverageData.Tracer) {
            # we used breakpoints to measure CC, clean them up
            Exit-CoverageAnalysis -CommandCoverage $coverageData.CommandCoverage
        }
    }
}
