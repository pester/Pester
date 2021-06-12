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

.PARAMETER ForEach
Allows data driven tests to be written.
Takes an array of data and generates one block for each item in the array, and makes the item
available as $_ in all child blocks. When the array is an array of hashtables, it additionally
defines each key in the hashatble as variable.

.EXAMPLE
```powershell
function Add-Numbers($a, $b) {
    return $a + $b
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


    if ($ExecutionContext.SessionState.PSVariable.Get('invokedViaInvokePester')) {
        if ($PSBoundParameters.ContainsKey('ForEach')) {
            if ($null -ne $ForEach -and 0 -lt @($ForEach).Count) {
                New-ParametrizedBlock -Name $Name -ScriptBlock $Fixture -StartLine $MyInvocation.ScriptLineNumber -Tag $Tag -FrameworkData @{ CommandUsed = 'Describe'; WrittenToScreen = $false } -Focus:$Focus -Skip:$Skip -Data $ForEach
            }
            else {
                # @() or $null is provided do nothing
            }
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

        if ($null -ne $script:lastExecutedAt -and ([datetime]::now - $script:lastExecutedAt).TotalMilliseconds -lt 100 -and $script:lastExecutedFile -eq $ScriptName) {
            # skip file if the same file was executed less than 100 ms ago. This is here because we will run the file from the first
            # describe and the subsequent describes in the same file would try to re-run the file. 100ms window should be good enough
            # to be transparent for the interactive use, yet big enough to advance from the end of the command to the next, even on slow systems
            # use the file name as well to allow running multiple files in sequence

            $script:lastExecutedFile = $ScriptName
            $script:lastExecutedAt = [datetime]::Now

            return
        }

        # we are invoking a file, try call Invoke-Pester on the whole file,
        # but make sure we are invoking it in the caller session state, because
        # paths don't stay attached to session state
        $invokePester = {
            param($private:Path, $private:ScriptParameters, $private:Out_Null)
            $private:c = New-PesterContainer -Path $Path -Data $ScriptParameters
            Invoke-Pester -Container $c Path | & $Out_Null
        }

        # get PSBoundParameters from caller script to allow interactive execution of parameterized tests.
        $scriptBoundParameters = $SessionState.PSVariable.GetValue("PSBoundParameters")

        Set-ScriptBlockScope -SessionState $SessionState -ScriptBlock $invokePester
        & $invokePester $ScriptName $scriptBoundParameters $SafeCommands['Out-Null']
        $script:lastExecutedFile = $ScriptName
        $script:lastExecutedAt = [datetime]::Now
    }
    else {
        throw "Pester can run only saved files interactively. Please save your file to a disk."

        # there is a number of problems with this that I don't know how to solve right now
        # - the scripblock below will be discovered which shows a weird message in the console (maybe just suppress?)
        # every block will get it's own summary if we ar running multiple of them (can we somehow get to the actuall executed code?) or know which one is the last one?

        # use an intermediate module to carry the bound paremeters
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
