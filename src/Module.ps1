﻿# Set-SessionStateHint -Hint Pester -SessionState $ExecutionContext.SessionState
# these functions will be shared with the mock bootstrap function, or used in mocked calls so let's capture them just once instead of everytime we use a mock
$script:SafeCommands['ExecutionContext'] = $ExecutionContext
$script:SafeCommands['Get-MockDynamicParameter'] = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Get-MockDynamicParameter', 'function')
$script:SafeCommands['Write-PesterDebugMessage'] = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Write-PesterDebugMessage', 'function')
$script:SafeCommands['Set-DynamicParameterVariable'] = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Set-DynamicParameterVariable', 'function')


& $SafeCommands['Set-Alias'] 'Add-AssertionOperator' 'Add-ShouldOperator'
& $SafeCommands['Set-Alias'] 'Get-AssertionOperator' 'Get-ShouldOperator'


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

    # export
    'Export-NunitReport'
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
)
