@{
    # Severity doesn't affect custom rules, so Measure-ObjectCmdlet (Information) is excluded below
    Severity            = @('Error', 'Warning')
    IncludeDefaultRules = $true
    CustomRulePath      = './Pester.BuildAnalyzerRules'
    ExcludeRules        = @(
        'PSUseShouldProcessForStateChangingFunctions'
        'PSUseApprovedVerbs'
        '*Manifest*' # Throws error due to missing PesterConfiguration.Format.ps1xml
    )
}
