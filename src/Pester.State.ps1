$script:AssertionOperators = [Collections.Generic.Dictionary[string,object]]([StringComparer]::InvariantCultureIgnoreCase)
$script:AssertionAliases = [Collections.Generic.Dictionary[string,object]]([StringComparer]::InvariantCultureIgnoreCase)
$script:AssertionDynamicParams = [Pester.Factory]::CreateRuntimeDefinedParameterDictionary()
$script:DisableScopeHints = $true
