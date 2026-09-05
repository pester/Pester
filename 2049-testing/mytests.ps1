$pesterConfig = [PesterConfiguration]::Default
$pesterConfig.TestResult.Enabled = $true
$pesterConfig.Run.Path = '.\2049.tests.ps1'
$pesterConfig.Run.PassThru = $true
$pesterConfig.Debug.WriteDebugMessages = $true

foreach ($fmt in 'NUnitXml NUnit2.5 NUnit3 JUnitXml'.split(' ')) {
    $pesterConfig.TestResult.OutputFormat = $fmt
    $pesterConfig.TestResult.OutputPath = "results.$fmt.xml"
    Invoke-Pester -Configuration $pesterConfig
}
