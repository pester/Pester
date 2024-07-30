function Describe {
    <#
    .SYNOPSIS
    Creates a logical group of tests.

    .DESCRIPTION
    Creates a logical group of tests. All Mocks, TestDrive and TestRegistry contents
    defined within a Describe block are scoped to that Describe; they
    will no longer be present when the Describe block exits.  A Describe
    block may contain any number of Context and It blocks.

    .PARAMETER Name
    The name of the test group. This is often an expressive phrase describing
    the scenario being tested.

    .PARAMETER Fixture
    The actual test script. If you are following the AAA pattern (Arrange-Act-Assert),
    this typically holds the arrange and act sections. The Asserts will also lie
    in this block but are typically nested each in its own It block. Assertions are
    typically performed by the Should command within the It blocks.

    .PARAMETER Tag
    Optional parameter containing an array of strings. When calling Invoke-Pester,
    it is possible to specify a -Tag parameter which will only execute Describe blocks
    containing the same Tag.

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

    Describe "Add-Numbers" {
        It "adds positive numbers" {
            $sum = Add-Numbers 2 3
            $sum | Should -Be 5
        }

        It "adds negative numbers" {
            $sum = Add-Numbers (-2) (-2)
            $sum | Should -Be (-4)
        }

        It "adds one negative number to positive number" {
            $sum = Add-Numbers (-2) 2
            $sum | Should -Be 0
        }

        It "concatenates strings if given strings" {
            $sum = Add-Numbers two three
            $sum | Should -Be "twothree"
        }
    }
    ```

    Using Describe to group tests logically at the root of the script/container

    .LINK
    https://pester.dev/docs/commands/Describe

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
    if ($null -eq $Fixture) {
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

            New-ParametrizedBlock -Name $Name -ScriptBlock $Fixture -StartLine $MyInvocation.ScriptLineNumber -StartColumn $MyInvocation.OffsetInLine -Tag $Tag -FrameworkData @{ CommandUsed = 'Describe'; WrittenToScreen = $false } -Focus:$Focus -Skip:$Skip -Data $ForEach
        }
        else {
            New-Block -Name $Name -ScriptBlock $Fixture -StartLine $MyInvocation.ScriptLineNumber -Tag $Tag -FrameworkData @{ CommandUsed = 'Describe'; WrittenToScreen = $false } -Focus:$Focus -Skip:$Skip
        }
    }
    else {
        Invoke-Interactively -CommandUsed 'Describe' -ScriptName $PSCmdlet.MyInvocation.ScriptName -SessionState $PSCmdlet.SessionState -BoundParameters $PSCmdlet.MyInvocation.BoundParameters
    }
}

function Invoke-Interactively ($CommandUsed, $ScriptName, $SessionState, $BoundParameters) {
    # interactive execution (by F5 in an editor, by F8 on selection, or by pasting to console)
    # do not run interactively in non-saved files
    # (vscode will use path like "untitled:Untitled-*" so we check if the path is rooted)
    if (-not [String]::IsNullOrEmpty($ScriptName) -and [IO.Path]::IsPathRooted($ScriptName)) {
        # we are invoking a file, try call Invoke-Pester on the whole file,
        # but make sure we are invoking it in the caller session state, because
        # paths don't stay attached to session state
        $invokePester = {
            param($private:Path, $private:ScriptParameters, $private:Out_Null)
            $private:c = New-PesterContainer -Path $Path -Data $ScriptParameters
            Invoke-Pester -Container $c | & $Out_Null
        }

        # get PSBoundParameters from caller script to allow interactive execution of parameterized tests.
        $scriptBoundParameters = $SessionState.PSVariable.GetValue("PSBoundParameters")

        Set-ScriptBlockScope -SessionState $SessionState -ScriptBlock $invokePester
        & $invokePester $ScriptName $scriptBoundParameters $SafeCommands['Out-Null']

        # exit the current script (always invoked test-file in this block) to avoid rerunning the next root-level block
        # and running any remaining root-level code. this will not kill a parent script or process.
        # pass on exit-code set by Invoke-Pester (always equal to failing tests count)
        exit $global:LASTEXITCODE
    }
    else {
        throw "Pester can run only saved files interactively. Please save your file to a disk."

        # there is a number of problems with this that I don't know how to solve right now
        # - the scripblock below will be discovered which shows a weird message in the console (maybe just suppress?)
        # every block will get it's own summary if we ar running multiple of them (can we somehow get to the actual executed code?) or know which one is the last one?

        # use an intermediate module to carry the bound parameters
        # but don't touch the session state the scriptblock is attached
        # to, this way we are still running the provided scriptblocks where
        # they are coming from (in the SessionState they are attached to),
        # this could be replaced by providing params if the current api allowed it
        $sb = & {
            # only local variables are copied in closure
            # make a new scope so we copy only what is needed
            param($BoundParameters, $CommandUsed)
            {
                & $CommandUsed @BoundParameters
            }.GetNewClosure()
        } $BoundParameters $CommandUsed

        Invoke-Pester -ScriptBlock $sb | & $SafeCommands['Out-Null']
    }
}

function Assert-DescribeInProgress {
    # TODO: Enforce block structure in the Runtime.Pester if needed, in the meantime this is just a placeholder
}
