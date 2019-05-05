function Get-CoveragePlugin {
    New-PluginObject -Name "Coverage" -OneTimeBlockSetupStart {
        param($Context)


        $config = $Context.Configuration['Coverage']
        $breakpoints = Enter-CoverageAnalysis -CodeCoverage $config
        $Context.Block.Root.PluginData.Add('Coverage', @{
            CommandCoverage = $breakpoints
            CoverageReport = $null
        })

    } -OneTimeBlockTeardownEnd {
        if ($Context.Block.Root.PluginData.ContainsKey('Coverage')) {
            $breakpoints = $Context.Block.Root.PluginData.Coverage.CommandCoverage

            $coverageReport = Get-CoverageReport -CommandCoverage $breakpoints
            $Context.Block.Root.PluginData.Coverage.CoverageReport = $coverageReport

            Exit-CoverageAnalysis -CommandCoverage $breakpoints
        }
    }
}
