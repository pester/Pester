function Is-CollectionSubsequence ($Expected, $Actual) {
    # Returns $true when every item of $Expected appears within $Actual in the same
    # relative order. Gaps between the matched items are allowed, but each $Actual item is
    # consumed at most once, so repeated items in $Expected need at least as many matching
    # items in $Actual (e.g. @(1, 1) needs two 1s in $Actual, not one reused twice).
    #
    # A single, non-collection value is treated as a one-item collection, which keeps the
    # original single-item containment behaviour as the one-item special case.

    # Materialise the expected items so we can index them by position. Adding them one by
    # one preserves each item as a single element, even when it is itself a collection,
    # which @(...) would otherwise flatten.
    $expectedItems = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $Expected) { $expectedItems.Add($item) }

    $expectedCount = $expectedItems.Count
    # An empty expected collection is vacuously present in any collection.
    if (0 -eq $expectedCount) { return $true }

    # Greedy two-pointer subsequence match: walk $Actual once and advance through the
    # expected items whenever the current actual item matches the next one we need. Matching
    # the earliest occurrence is always safe for a subsequence, so a single pass is enough.
    $matchIndex = 0
    foreach ($actualItem in $Actual) {
        # Compare with -eq, actual item on the left, to match the equality semantics of
        # PowerShell's -contains operator. Cast to [bool] so an actual item that is itself a
        # collection collapses to a single truthy/falsy result instead of a filtered array.
        if ([bool]($actualItem -eq $expectedItems[$matchIndex])) {
            $matchIndex++
            if ($matchIndex -eq $expectedCount) { return $true }
        }
    }

    return $false
}
