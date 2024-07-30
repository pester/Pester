function Context {
    <#
    .SYNOPSIS
    Provides logical grouping of It blocks within a single Describe block.

    .DESCRIPTION
    Provides logical grouping of It blocks within a single Describe block.
    Any Mocks defined inside a Context are removed at the end of the Context scope,
    as are any files or folders added to the TestDrive during the Context block's
    execution. Any BeforeEach or AfterEach blocks defined inside a Context also only
    apply to tests within that Context .

    .PARAMETER Name
    The name of the Context. This is a phrase describing a set of tests within a describe.

    .PARAMETER Tag
    Optional parameter containing an array of strings. When calling Invoke-Pester,
    it is possible to specify a -Tag parameter which will only execute Context blocks
    containing the same Tag.

    .PARAMETER Fixture
    Script that is executed. This may include setup specific to the context
    and one or more It blocks that validate the expected outcomes.

    .PARAMETER Skip
    Use this parameter to explicitly mark the block to be skipped. This is preferable to temporarily
    commenting out a block, because it remains listed in the output.

    .PARAMETER AllowNullOrEmptyForEach
    Allows empty or null values for -ForEach when Run.FailOnNullOrEmptyForEach is enabled.
    This might be excepted in certain scenarios like using external data.

    .PARAMETER ForEach
    Allows data driven tests to be written.
    Takes an array of data and generates one block for each item in the array, and makes the item
    available as $_ in all child blocks. When the array is an array of hashtables, it additionally
    defines each key in the hashtable as variable.

    .EXAMPLE
    ```powershell
    BeforeAll {
        function Add-Numbers($a, $b) {
            return $a + $b
        }
    }

    Describe 'Add-Numbers' {
        Context 'when adding positive values' {
            It '...' {
                # ...
            }
        }

        Context 'when adding negative values' {
            It '...' {
                # ...
            }
            It '...' {
                # ...
            }
        }
    }
    ```

    Example of how to use Context for grouping different tests

    .LINK
    https://pester.dev/docs/commands/Context

    .LINK
    https://pester.dev/docs/usage/test-file-structure

    .LINK
    https://pester.dev/docs/usage/mocking

    .LINK
    https://pester.dev/docs/usage/testdrive
    #>
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Name,

        [Alias('Tags')]
        [string[]] $Tag = @(),

        [Parameter(Position = 1)]
        [ValidateNotNull()]
        [ScriptBlock] $Fixture,

        # [Switch] $Focus,
        [Switch] $Skip,
        [Switch] $AllowNullOrEmptyForEach,

        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidAssignmentToAutomaticVariable', '', Justification = 'ForEach is not used in Foreach-Object loop')]
        $ForEach
    )

    $Focus = $false
    if ($Fixture -eq $null) {
        if ($Name.Contains("`n")) {
            throw "Test fixture name has multiple lines and no test fixture is provided. (Have you provided a name for the test group?)"
        }
        else {
            throw 'No test fixture is provided. (Have you put the open curly brace on the next line?)'
        }
    }

    Assert-BoundScriptBlockInput -ScriptBlock $Fixture

    if ($ExecutionContext.SessionState.PSVariable.Get('invokedViaInvokePester')) {
        if ($state.CurrentBlock.IsRoot -and -not $state.CurrentBlock.FrameworkData.MissingParametersProcessed) {
            # For undefined parameters in container, add parameter's default value to Data
            Add-MissingContainerParameters -RootBlock $state.CurrentBlock -Container $container -CallingFunction $PSCmdlet
        }

        if ($PSBoundParameters.ContainsKey('ForEach')) {
            if ($null -eq $ForEach -or 0 -eq @($ForEach).Count) {
                if ($PesterPreference.Run.FailOnNullOrEmptyForEach.Value -and -not $AllowNullOrEmptyForEach) {
                    throw [System.ArgumentException]::new('Value can not be null or empty array. If this is expected, use -AllowNullOrEmptyForEach', 'ForEach')
                }
                # @() or $null is provided and allowed, do nothing
                return
            }

            New-ParametrizedBlock -Name $Name -ScriptBlock $Fixture -StartLine $MyInvocation.ScriptLineNumber -StartColumn $MyInvocation.OffsetInLine -Tag $Tag -FrameworkData @{ CommandUsed = 'Context'; WrittenToScreen = $false } -Focus:$Focus -Skip:$Skip -Data $ForEach
        }
        else {
            New-Block -Name $Name -ScriptBlock $Fixture -StartLine $MyInvocation.ScriptLineNumber -Tag $Tag -FrameworkData @{ CommandUsed = 'Context'; WrittenToScreen = $false } -Focus:$Focus -Skip:$Skip
        }
    }
    else {
        Invoke-Interactively -CommandUsed 'Context' -ScriptName $PSCmdlet.MyInvocation.ScriptName -SessionState $PSCmdlet.SessionState -BoundParameters $PSCmdlet.MyInvocation.BoundParameters
    }
}
