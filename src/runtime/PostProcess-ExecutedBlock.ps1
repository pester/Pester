function PostProcess-ExecutedBlock {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Block
    )


    # traverses the block structure after a block was executed and
    # and sets the failures correctly so the aggreagatted failures
    # propagate towards the root so if a child test fails it's block
    # aggregated result should be marked as failed

    process {
        foreach ($b in $Block) {
            $thisBlockFailed = -not $b.OwnPassed

            $b.OwnTotalCount = 0
            $b.OwnFailedCount = 0
            $b.OwnPassedCount = 0
            $b.OwnSkippedCount = 0
            $b.OwnNotRunCount = 0

            $testDuration = [TimeSpan]::Zero

            foreach ($t in $b.Tests) {
                $testDuration += $t.Duration

                $b.OwnTotalCount++
                if (-not $t.ShouldRun) {
                    $b.OwnNotRunCount++
                }
                elseif ($t.ShouldRun -and $t.Skipped) {
                    $b.OwnSkippedCount++
                }
                elseif (($t.Executed -and -not $t.Passed) -or ($t.ShouldRun -and -not $t.Executed)) {
                    # TODO:  this condition works but needs to be revisited. when the parent fails the test is marked as failed, because it should have run but it did not,and but there is no error in the test result, in such case all tests should probably add error or a flag that indicates that the parent failed, or a log or something, but error is probably the best
                    $b.OwnFailedCount++
                }
                elseif ($t.Executed -and $t.Passed) {
                    $b.OwnPassedCount++
                }
                else {
                    throw "Test '$($t.Name)' is in invalid state. $($t | Format-List -Force * | & $SafeCommands['Out-String'])"
                }
            }

            $anyTestFailed = 0 -lt $b.OwnFailedCount

            $childBlocks = $b.Blocks
            $anyChildBlockFailed = $false
            $aggregatedChildDuration = [TimeSpan]::Zero
            if (none $childBlocks) {
                # one thing to consider here is what happens when a block fails, in the current
                # excecution model the block can fail when a setup or teardown fails, with failed
                # setup it is easy all the tests in the block are considered failed, with teardown
                # not so much, when all tests pass and the teardown itself fails what should be the result?



                # todo: there are two concepts mixed with the "own", because the duration and the test counts act differently. With the counting we are using own as "the count of the tests in this block", but with duration the "own" means "self", that is how long this block itself has run, without the tests. This information might not be important but this should be cleared up before shipping. Same goes with the relation to failure, ownPassed means that the block itself passed (that is no setup or teardown failed in it), even though the underlying tests might fail.


                $b.OwnDuration = $b.Duration - $testDuration

                $b.Passed = -not ($thisBlockFailed -or $anyTestFailed)

                # we have no child blocks so the own counts are the same as the total counts
                $b.TotalCount = $b.OwnTotalCount
                $b.FailedCount = $b.OwnFailedCount
                $b.PassedCount = $b.OwnPassedCount
                $b.SkippedCount = $b.OwnSkippedCount
                $b.NotRunCount = $b.OwnNotRunCount
            }
            else {
                # when we have children we first let them process themselves and
                # then we add the results together (the recusion could reach to the parent and add the totals)
                # but that is difficult with the duration, so this way is less error prone
                PostProcess-ExecutedBlock -Block $childBlocks

                foreach ($child in $childBlocks) {
                    # check that no child block failed, the Passed is aggregate failed, so it will be false
                    # when any test fails in the child, or if the block itself fails
                    if ($child.ShouldRun -and -not $child.Passed) {
                        $anyChildBlockFailed = $true
                    }

                    $aggregatedChildDuration += $child.Duration

                    $b.TotalCount += $child.TotalCount
                    $b.PassedCount += $child.PassedCount
                    $b.FailedCount += $child.FailedCount
                    $b.SkippedCount += $child.SkippedCount
                    $b.NotRunCount += $child.NotRunCount
                }

                # then we add counts from this block to the counts from the children blocks
                $b.TotalCount += $b.OwnTotalCount
                $b.PassedCount += $b.OwnPassedCount
                $b.FailedCount += $b.OwnFailedCount
                $b.SkippedCount += $b.OwnSkippedCount
                $b.NotRunCount += $b.OwnNotRunCount

                $b.Passed = -not ($thisBlockFailed -or $anyTestFailed -or $anyChildBlockFailed)
                $b.OwnDuration = $b.Duration - $testDuration - $aggregatedChildDuration
            }
        }
    }
}
