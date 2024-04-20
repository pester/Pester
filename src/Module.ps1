# Set-SessionStateHint -Hint Pester -SessionState $ExecutionContext.SessionState
# these functions will be shared with the mock bootstrap function, or used in mocked calls so let's capture them just once instead of every time we use a mock
$script:SafeCommands['ExecutionContext'] = $ExecutionContext
$script:SafeCommands['Get-MockDynamicParameter'] = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Get-MockDynamicParameter', 'function')
$script:SafeCommands['Write-PesterDebugMessage'] = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Write-PesterDebugMessage', 'function')
$script:SafeCommands['Set-DynamicParameterVariable'] = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Set-DynamicParameterVariable', 'function')

& $SafeCommands['Set-Alias'] 'Add-AssertionOperator'        'Add-ShouldOperator'
& $SafeCommands['Set-Alias'] 'Get-AssertionOperator'        'Get-ShouldOperator'

& $SafeCommands['Set-Alias'] 'Should-BeFalse'               'Assert-False'
& $SafeCommands['Set-Alias'] 'Should-BeTrue'                'Assert-True'
& $SafeCommands['Set-Alias'] 'Should-All'                   'Assert-All'
& $SafeCommands['Set-Alias'] 'Should-Any'                   'Assert-Any'
& $SafeCommands['Set-Alias'] 'Should-Contain'               'Assert-Contain'
& $SafeCommands['Set-Alias'] 'Should-NotContain'            'Assert-NotContain'
& $SafeCommands['Set-Alias'] 'Should-BeEquivalent'          'Assert-Equivalent'
& $SafeCommands['Set-Alias'] 'Should-Throw'                 'Assert-Throw'
& $SafeCommands['Set-Alias'] 'Should-BeEqual'               'Assert-Equal'
& $SafeCommands['Set-Alias'] 'Should-BeGreaterThan'         'Assert-GreaterThan'
& $SafeCommands['Set-Alias'] 'Should-BeGreaterThanOrEqual'  'Assert-GreaterThanOrEqual'
& $SafeCommands['Set-Alias'] 'Should-BeLessThan'            'Assert-LessThan'
& $SafeCommands['Set-Alias'] 'Should-BeLessThanOrEqual'     'Assert-LessThanOrEqual'
& $SafeCommands['Set-Alias'] 'Should-NotBeEqual'            'Assert-NotEqual'
& $SafeCommands['Set-Alias'] 'Should-NotBeNull'             'Assert-NotNull'
& $SafeCommands['Set-Alias'] 'Should-NotBeSame'             'Assert-NotSame'
& $SafeCommands['Set-Alias'] 'Should-NotBeType'             'Assert-NotType'
& $SafeCommands['Set-Alias'] 'Should-BeNull'                'Assert-Null'
& $SafeCommands['Set-Alias'] 'Should-BeSame'                'Assert-Same'
& $SafeCommands['Set-Alias'] 'Should-BeType'                'Assert-Type'

& $SafeCommands['Set-Alias'] 'Should-BeString'              'Assert-StringEqual'
& $SafeCommands['Set-Alias'] 'Should-NotBeString'              'Assert-StringNotEqual'
& $SafeCommands['Set-Alias'] 'Should-BeLikeString'          'Assert-Like'
& $SafeCommands['Set-Alias'] 'Should-NotBeLikeString'       'Assert-NotLike'

& $SafeCommands['Set-Alias'] 'Should-BeEmptyString'         'Assert-StringEmpty'
& $SafeCommands['Set-Alias'] 'Should-NotBeNullOrWhiteSpaceString'         'Assert-StringNotWhiteSpace'
& $SafeCommands['Set-Alias'] 'Should-NotBeNullOrEmptyString'         'Assert-StringNotEmpty'




& $SafeCommands['Update-TypeData'] -TypeName PesterConfiguration -TypeConverter 'PesterConfigurationDeserializer' -SerializationDepth 5 -Force
& $SafeCommands['Update-TypeData'] -TypeName 'Deserialized.PesterConfiguration' -TargetTypeForDeserialization PesterConfiguration -Force

& $script:SafeCommands['Export-ModuleMember'] @(
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
    'Assert-False'
    'Assert-True'
    'Assert-All'
    'Assert-Any'
    'Assert-Contain'
    'Assert-NotContain'
    'Assert-Equivalent'
    'Assert-Throw'
    'Assert-Equal'
    'Assert-GreaterThan'
    'Assert-GreaterThanOrEqual'
    'Assert-LessThan'
    'Assert-LessThanOrEqual'
    'Assert-NotEqual'
    'Assert-NotNull'
    'Assert-NotSame'
    'Assert-NotType'
    'Assert-Null'
    'Assert-Same'
    'Assert-Type'

    'Assert-Like'
    'Assert-NotLike'
    'Assert-StringEqual'
    'Assert-StringNotEqual'

    'Assert-StringEmpty'
    'Assert-StringNotWhiteSpace'
    'Assert-StringNotEmpty'

    # export
    'Export-NUnitReport'
    'ConvertTo-NUnitReport'
    'Export-JUnitReport'
    'ConvertTo-JUnitReport'
    'ConvertTo-Pester4Result'

    # legacy
    'Assert-VerifiableMock'
    'Assert-MockCalled'
    'Set-ItResult'
    'New-MockObject'

    'New-Fixture'
) -Alias @(
    'Add-AssertionOperator'
    'Get-AssertionOperator'

    # assertion functions
    # bool
    'Should-BeFalse'
    'Should-BeTrue'

    # collection
    'Should-All'
    'Should-Any'
    'Should-Contain'
    'Should-NotContain'
    'Should-BeEquivalent'
    'Should-Throw'
    'Should-BeEqual'
    'Should-BeGreaterThan'
    'Should-BeGreaterThanOrEqual'
    'Should-BeLessThan'
    'Should-BeLessThanOrEqual'
    'Should-NotBeEqual'
    'Should-NotBeNull'
    'Should-NotBeSame'
    'Should-NotBeType'
    'Should-BeNull'
    'Should-BeSame'
    'Should-BeType'

    # string
    'Should-BeString'
    'Should-NotBeString'

    'Should-BeEmptyString'
    'Should-NotBeNullOrWhiteSpaceString'
    'Should-NotBeNullOrEmptyString'

    'Should-BeLikeString'
    'Should-NotBeLikeString'
)
