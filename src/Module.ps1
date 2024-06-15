# Set-SessionStateHint -Hint Pester -SessionState $ExecutionContext.SessionState
# these functions will be shared with the mock bootstrap function, or used in mocked calls so let's capture them just once instead of every time we use a mock
$script:SafeCommands['ExecutionContext'] = $ExecutionContext
$script:SafeCommands['Get-MockDynamicParameter'] = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Get-MockDynamicParameter', 'function')
$script:SafeCommands['Write-PesterDebugMessage'] = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Write-PesterDebugMessage', 'function')
$script:SafeCommands['Set-DynamicParameterVariable'] = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Set-DynamicParameterVariable', 'function')

& $SafeCommands['Set-Alias'] 'Add-AssertionOperator'        'Add-ShouldOperator'
& $SafeCommands['Set-Alias'] 'Get-AssertionOperator'        'Get-ShouldOperator'




& $SafeCommands['Update-TypeData'] -TypeName PesterConfiguration -TypeConverter 'PesterConfigurationDeserializer' -SerializationDepth 5 -Force
& $SafeCommands['Update-TypeData'] -TypeName 'Deserialized.PesterConfiguration' -TargetTypeForDeserialization PesterConfiguration -Force

[Pester.VerbsPatcher]::AllowShouldVerb($PSVersionTable.PSVersion.Major)

& $script:SafeCommands['Export-ModuleMember'] -Function @(
    'Invoke-Pester'

    # blocks
    'Describe'
    'Context'
    'It'

    # mocking
    'Mock'
    'InModuleScope'

    # setups
    'BeforeDiscovery'
    'BeforeAll'
    'BeforeEach'
    'AfterEach'
    'AfterAll'

    # should
    'Should'
    'Add-ShouldOperator'
    'Get-ShouldOperator'

    # config
    'New-PesterContainer'
    'New-PesterConfiguration'

    # assert
    # bool
    'Should-BeFalse'
    'Should-BeTrue'
    'Should-BeFalsy'
    'Should-BeTruthy'

    # collection
    'Should-All'
    'Should-Any'
    'Should-ContainCollection'
    'Should-NotContainCollection'
    'Should-BeCollection'
    'Should-BeEquivalent'
    'Should-Throw'
    'Should-Be'
    'Should-BeGreaterThan'
    'Should-BeGreaterThanOrEqual'
    'Should-BeLessThan'
    'Should-BeLessThanOrEqual'
    'Should-NotBe'
    'Should-NotBeNull'
    'Should-NotBeSame'
    'Should-NotHaveType'
    'Should-BeNull'
    'Should-BeSame'
    'Should-HaveType'

    # string
    'Should-BeString'
    'Should-NotBeString'

    'Should-BeEmptyString'

    'Should-NotBeWhiteSpaceString'
    'Should-NotBeEmptyString'

    'Should-BeLikeString'
    'Should-NotBeLikeString'

    'Should-BeFasterThan'
    'Should-BeSlowerThan'
    'Should-BeBefore'
    'Should-BeAfter'

    # export
    'Export-NUnitReport'
    'ConvertTo-NUnitReport'
    'Export-JUnitReport'
    'ConvertTo-JUnitReport'
    'ConvertTo-Pester4Result'

    # helpers
    'New-MockObject'
    'New-Fixture'
    'Set-ItResult'
) -Alias @(
    'Add-AssertionOperator'
    'Get-AssertionOperator'
)
