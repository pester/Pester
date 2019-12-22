function Get-CoveragePlugin {
    New-PluginObject -Name "Coverage" -Start {
        param($Context)
        $config = $Context.Configuration['Coverage']
        $breakpoints = Enter-CoverageAnalysis -CodeCoverage $config
        $Context.GlobalPluginData.Add('Coverage', @{
            CommandCoverage = $breakpoints
            CoverageReport = $null
        })
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
