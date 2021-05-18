function New-Block {
    # endpoint for adding a block that contains tests
    # or other blocks

    param (
        [Parameter(Mandatory = $true)]
        [String] $Name,
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $ScriptBlock,
        [int] $StartLine = $MyInvocation.ScriptLineNumber,
        [String[]] $Tag = @(),
        [HashTable] $FrameworkData = @{ },
        [Switch] $Focus,
        [String] $Id,
        [Switch] $Skip,
        $Data
    )

    # Switch-Timer -Scope Framework
    # $overheadStartTime = $state.FrameworkStopWatch.Elapsed
    # $blockStartTime = $state.UserCodeStopWatch.Elapsed

    $state.Stack.Push($Name)
    $path = @( <# Get full name #> $history = $state.Stack.ToArray(); [Array]::Reverse($history); $history)
    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope Runtime "Entering path $($path -join '.')"
    }

    $block = $null
    $previousBlock = $state.CurrentBlock

    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
        Write-PesterDebugMessage -Scope DiscoveryCore "Adding block $Name to discovered blocks"
    }

    # new block
    $block = [Pester.Block]::Create()
    $block.Name = $Name
    # using the non-expanded name as default to fallback to it if we don't
    # reach the point where we expand it, for example because of setup failure
    $block.ExpandedName = $Name

    $block.Path = $Path
    # using the non-expanded path as default to fallback to it if we don't
    # reach the point where we expand it, for example because of setup failure
    $block.ExpandedPath = $Path -join '.'
    $block.Tag = $Tag
    $block.ScriptBlock = $ScriptBlock
    $block.StartLine = $StartLine
    $block.FrameworkData = $FrameworkData
    $block.Focus = $Focus
    $block.Id = $Id
    $block.Skip = $Skip
    $block.Data = $Data

    # we attach the current block to the parent, and put it to the parent
    # lists
    $block.Parent = $state.CurrentBlock
    $state.CurrentBlock.Order.Add($block)
    $state.CurrentBlock.Blocks.Add($block)

    # and then make it the new current block
    $state.CurrentBlock = $block
    try {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope DiscoveryCore "Discovering in body of block $Name"
        }

        if ($null -ne $block.Data) {
            $context = @{}
            Add-DataToContext -Destination $context -Data $block.Data

            $setVariablesAndRunBlock = {
                param ($private:______parameters)

                foreach ($private:______current in $private:______parameters.Context.GetEnumerator()) {
                    $ExecutionContext.SessionState.PSVariable.Set($private:______current.Key, $private:______current.Value)
                }

                $private:______current = $null

                . $private:______parameters.ScriptBlock
            }

            $parameters = @{
                Context     = $context
                ScriptBlock = $ScriptBlock
            }

            $SessionStateInternal = $script:ScriptBlockSessionStateInternalProperty.GetValue($ScriptBlock, $null)
            $script:ScriptBlockSessionStateInternalProperty.SetValue($setVariablesAndRunBlock, $SessionStateInternal, $null)

            & $setVariablesAndRunBlock $parameters
        }
        else {
            & $ScriptBlock
        }

        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope DiscoveryCore "Finished discovering in body of block $Name"
        }
    }
    finally {
        $state.CurrentBlock = $previousBlock
        $null = $state.Stack.Pop()
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            Write-PesterDebugMessage -Scope Runtime "Left block $Name"
        }
    }
}
