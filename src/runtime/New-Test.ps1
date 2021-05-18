function New-Test {
    # endpoint for adding a test

    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String] $Name,
        [Parameter(Mandatory = $true, Position = 1)]
        [ScriptBlock] $ScriptBlock,
        [int] $StartLine = $MyInvocation.ScriptLineNumber,
        [String[]] $Tag = @(),
        $Data,
        [String] $Id,
        [Switch] $Focus,
        [Switch] $Skip
    )

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope DiscoveryCore "Entering test $Name"
    }

    if ($state.CurrentBlock.IsRoot) {
        throw "Test cannot be directly in the root."
    }

    # avoid managing state by not pushing to the stack only to pop out in finally
    # simply concatenate the arrays
    $path = @(<# Get full name #> $history = $state.Stack.ToArray(); [Array]::Reverse($history); $history + $name)

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Runtime "Entering path $($path -join '.')"
    }

    $test = [Pester.Test]::Create()
    $test.Id = $Id
    $test.ScriptBlock = $ScriptBlock
    $test.Name = $Name
    # using the non-expanded name as default to fallback to it if we don't
    # reach the point where we expand it, for example because of setup failure
    $test.ExpandedName = $Name
    $test.Path = $path
    # using the non-expanded path as default to fallback to it if we don't
    # reach the point where we expand it, for example because of setup failure
    $test.ExpandedPath = $path -join '.'
    $test.StartLine = $StartLine
    $test.Tag = $Tag
    $test.Focus = $Focus
    $test.Skip = $Skip
    $test.Data = $Data
    $test.FrameworkData.Runtime.Phase = 'Discovery'

    # add test to current block lists
    $state.CurrentBlock.Tests.Add($Test)
    $state.CurrentBlock.Order.Add($Test)

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope DiscoveryCore "Added test '$Name'"
    }
}
