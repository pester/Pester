function PostProcess-DiscoveredBlock {
    param (
        [Parameter(Mandatory = $true)]
        $Block,
        $Filter,
        $BlockContainer,
        [Parameter(Mandatory = $true)]
        $RootBlock
    )

    # pass array of blocks rather than 1 block to cross the function boundary
    # as few times as we can
    foreach ($b in $Block) {
        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
            $path = $b.Path -join "."
        }

        # traverses the block structure after a block was found and
        # link childs to their parents, filter blocks and tests to
        # determine which should run, and mark blocks and tests
        # as first or last to know when one time setups & teardowns should run
        $b.IsRoot = $b -eq $RootBlock
        $b.Root = $RootBlock
        $b.BlockContainer = $BlockContainer

        $tests = $b.Tests

        if ($b.IsRoot) {
            $b.Explicit = $false
            $b.Exclude = $false
            $b.Include = $false
            $b.ShouldRun = $true
        }
        else {
            $shouldRun = (Test-ShouldRun -Item $b -Filter $Filter)
            $b.Explicit = $shouldRun.Explicit

            if (-not $shouldRun.Exclude -and -not $shouldRun.Include) {
                $b.ShouldRun = $true
            }
            elseif ($shouldRun.Include) {
                $b.ShouldRun = $true
            }
            elseif ($shouldRun.Exclude) {
                $b.ShouldRun = $false
            }
            else {
                throw "Unknown combination of include exclude $($shouldRun)"
            }

            $b.Include = $shouldRun.Include -and -not $shouldRun.Exclude
            $b.Exclude = $shouldRun.Exclude
        }

        $parentBlockIsSkipped = (-not $b.IsRoot -and $b.Parent.Skip)

        if ($b.Skip) {
            if ($b.Explicit) {
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Skip "($path) Block was marked as skipped, but will not be skipped because it was explicitly requested to run."
                }

                $b.Skip = $false
            }
            else {
                if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                    Write-PesterDebugMessage -Scope Skip "($path) Block is skipped."
                }

                $b.Skip = $true
            }
        }
        elseif ($parentBlockIsSkipped) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Skip "($path) Block is skipped because a parent block was skipped."
            }

            $b.Skip = $true
        }

        $blockShouldRun = $false
        if ($tests.Count -gt 0) {
            foreach ($t in $tests) {
                $t.Block = $b

                if ($t.Block.Exclude) {
                    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                        $path = $t.Path -join "."
                        Write-PesterDebugMessage -Scope Filter "($path) Test is excluded because parent block was excluded."
                    }
                    $t.ShouldRun = $false
                }
                else {
                    # run the exlude filters before checking if the parent is included
                    # otherwise you would include tests that could match the exclude rule
                    $shouldRun = (Test-ShouldRun -Item $t -Filter $Filter)
                    $t.Explicit = $shouldRun.Explicit

                    if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                        $path = $t.Path -join "."
                    }

                    if (-not $shouldRun.Include -and -not $shouldRun.Exclude) {
                        $t.ShouldRun = $false
                    }
                    elseif ($shouldRun.Include) {
                        $t.ShouldRun = $true
                    }
                    elseif ($shouldRun.Exclude) {
                        $t.ShouldRun = $false
                    }
                    else {
                        throw "Unknown combination of ShouldRun $ShouldRun"
                    }
                }

                if ($t.Skip) {
                    if ($t.ShouldRun -and $t.Explicit) {
                        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                            Write-PesterDebugMessage -Scope Skip "($path) Test was marked as skipped, but will not be skipped because it was explicitly requested to run."
                        }

                        $t.Skip = $false
                    }
                    else {
                        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                            Write-PesterDebugMessage -Scope Skip "($path) Test is skipped."
                        }

                        $t.Skip = $true
                    }
                }
                elseif ($b.Skip) {
                    if ($t.ShouldRun -and $t.Explicit) {
                        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                            Write-PesterDebugMessage -Scope Skip "($path) Test was marked as skipped, because its parent was marked as skipped, but will not be skipped because it was explicitly requested to run."
                        }

                        $t.Skip = $false
                    }
                    else {
                        if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                            Write-PesterDebugMessage -Scope Skip "($path) Test is skipped because a parent block was skipped."
                        }

                        $t.Skip = $true
                    }
                }
            }


            # if we determined that the block should run we can still make it not run if
            # none of it's children will run
            if ($b.ShouldRun) {
                $testsToRun = foreach ($t in $tests) { if ($t.ShouldRun) { $t } }
                if ($testsToRun -and 0 -ne $testsToRun.Count) {
                    $testsToRun[0].First = $true
                    $testsToRun[-1].Last = $true
                    $blockShouldRun = $true
                }
            }
        }

        $childBlocks = $b.Blocks
        $anyChildBlockShouldRun = $false
        if ($childBlocks.Count -gt 0) {
            foreach ($cb in $childBlocks) {
                $cb.Parent = $b
            }

            # passing the array as a whole to cross the function boundary as few times as I can
            PostProcess-DiscoveredBlock -Block $childBlocks -Filter $Filter -BlockContainer $BlockContainer -RootBlock $RootBlock

            $childBlocksToRun = foreach ($cb in $childBlocks) { if ($cb.ShouldRun) { $cb } }
            $anyChildBlockShouldRun = $childBlocksToRun -and 0 -ne $childBlocksToRun.Count
            if ($anyChildBlockShouldRun) {
                $childBlocksToRun[0].First = $true
                $childBlocksToRun[-1].Last = $true
            }
        }

        $shouldRunBasedOnChildren = $blockShouldRun -or $anyChildBlockShouldRun

        if ($b.ShouldRun -and -not $shouldRunBasedOnChildren) {
            if ($PesterPreference.Debug.WriteDebugMessages.Value) {
                Write-PesterDebugMessage -Scope Filter "($($b.Path -join '.')) Block was marked as Should run based on filters, but none of its tests or tests in children blocks were marked as should run. So the block won't run."
            }
        }

        $b.ShouldRun = $shouldRunBasedOnChildren
    }
}
