function Get-CoveragePlugin {
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

        $breakpoints = Enter-CoverageAnalysis -CodeCoverage $config -Logger $logger

        $Context.Data.Add('Coverage', @{
            CommandCoverage = $breakpoints
            CoverageReport = $null
        })

        $count = @($breakpoints).Count
        if ($null -ne $logger) {
            & $logger "Added $count breakpoints in $($sw.ElapsedMilliseconds) ms."
        }
        if ($PesterPreference.Output.Verbosity.Value -in "Detailed", "Diagnostic") {
            & $SafeCommands["Write-Host"] -ForegroundColor Magenta "Code Coverage set $count breakpoints in $($sw.ElapsedMilliseconds) ms."
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
