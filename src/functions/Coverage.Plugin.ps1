function Get-CoveragePlugin {
    New-PluginObject -Name "Coverage" -RunStart {
        param($Context)

        [Reflection.Assembly]::LoadFrom("C:\p\profiler\csharp\Profiler\bin\Debug\netstandard2.0\Profiler.dll")
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
            $l = [Collections.Generic.List[Profiler.CodeCoveragePoint]]@()
            foreach ($breakpoint in $breakpoints) {
                $location = $breakpoint.BreakpointLocation
                $l.Add([Profiler.CodeCoveragePoint]::new($location.Path, $location.Line, $location.Column, ""));
            }

        }

        $Context.Data.Add('Coverage', @{
            CommandCoverage = $breakpoints
            CoveragePoints = $l
            CoverageReport = $null
            Measure = $null
        })

        if ($PesterPreference.Output.Verbosity.Value -in "Detailed", "Diagnostic") {
            & $SafeCommands["Write-Host"] -ForegroundColor Magenta "Code Coverage preparation finished after $($sw.ElapsedMilliseconds) ms."
        }
    } -End {
        param($Context)

        if (-not $Context.TestRun.PluginData.ContainsKey("Coverage")) {
            return
        }

        $coverageData = $Context.TestRun.PluginData.Coverage
        #TODO: rather check the config to see which mode of coverage we used
        if ($null -eq $coverageData.Measure) {
            # we used breakpoints to measure CC, clean them up
            Exit-CoverageAnalysis -CommandCoverage $coverageData.CommandCoverage
        }
    }
}
