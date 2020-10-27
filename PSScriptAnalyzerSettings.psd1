@{
    Severity = @('Error','Warning')
    IncludeDefaultRules = $true
    CustomRulePath = './PesterAnalyzerRules'
    ExcludeRules=@(
        'PSAvoidUsingWriteHost'
        'PSUseApprovedVerbs'
    )
}
