function Get-CoveragePlugin {
    New-PluginObject -Name "Coverage" -Start {
        param($Context)

        $logger = if ($Context.WriteDebugMessages) {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
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

        $config = $Context.Configuration['Coverage']

        if ($null -ne $logger) {
            & $logger "Config: $config"
        }

        $breakpoints = Enter-CoverageAnalysis -CodeCoverage $config -Logger $logger

        $Context.GlobalPluginData.Add('Coverage', @{
            CommandCoverage = $breakpoints
            CoverageReport = $null
        })

        if ($null -ne $logger) {
            & $logger "Added $($breakpoints.Counts) breakpoints in $($sw.ElapsedMilliseconds) ms."
        }
    } -End {
        param($Context)

        if (-not $Context.TestRun.PluginData.ContainsKey("Coverage")) {
            return
        }

        $coverageData = $Context.TestRun.PluginData.Coverage
        $breakpoints = $coverageData.CommandCoverage

        Exit-CoverageAnalysis -CommandCoverage $breakpoints
    }
}
