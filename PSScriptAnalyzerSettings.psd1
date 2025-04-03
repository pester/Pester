@{
    Severity            = @('Error', 'Warning')

    IncludeDefaultRules = $true
    CustomRulePath      = './Pester.BuildAnalyzerRules'
    ExcludeRules        = @(
        'PSUseShouldProcessForStateChangingFunctions'
        'PSUseApprovedVerbs'
        'Measure-SafeCommands'
    )
}
