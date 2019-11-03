function Get-CoveragePlugin {
    New-PluginObject -Name "Coverage" -OneTimeBlockSetupStart {
        param($Context)

        # this will run on every block but coverage is stored in the root
        # so we only need to add the key and the coverage once
        if (-not $Context.Block.Root.PluginData.ContainsKey('Coverage')) {
            $config = $Context.Configuration['Coverage']
            $breakpoints = Enter-CoverageAnalysis -CodeCoverage $config

            $Context.Block.Root.PluginData.Add('Coverage', @{
                CommandCoverage = $breakpoints
                CoverageReport = $null
            })
        }

    } -OneTimeBlockTeardownEnd {
        if ($Context.Block.Root.PluginData.ContainsKey('Coverage')) {
            $breakpoints = $Context.Block.Root.PluginData.Coverage.CommandCoverage

            $coverageReport = Get-CoverageReport -CommandCoverage $breakpoints
            $Context.Block.Root.PluginData.Coverage.CoverageReport = $coverageReport

            # TODO: Is the duration correct?
            $jaCoCoReport = Get-JaCoCoReportXml -CommandCoverage $breakpoints -TotalMilliseconds $Context.Block.Duration.TotalMilliseconds -CoverageReport $coverageReport
            $jaCoCoReport | & $SafeCommands['Out-File'] 'coverage.xml' -Encoding UTF8

            Exit-CoverageAnalysis -CommandCoverage $breakpoints
        }
    }
}
