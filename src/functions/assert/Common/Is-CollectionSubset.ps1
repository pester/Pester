function Is-CollectionSubset ($Expected, $Actual) {
    # Returns $true when every item of $Expected can be matched to a distinct item of $Actual,
    # ignoring order. This is a multiset (bag) subset check: each $Actual item is consumed at
    # most once, so repeated items in $Expected need at least as many matching items in $Actual
    # (e.g. @(1, 1) needs two 1s in $Actual, not one reused twice). This is the order-insensitive
    # counterpart to Is-CollectionSubsequence.
    #
    # A single, non-collection value is treated as a one-item collection, which keeps the
    # original single-item containment behaviour as the one-item special case.

    # Materialise the expected items so we can iterate them without flattening nested
    # collections, the same way @(...) would.
    $expectedItems = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $Expected) { $expectedItems.Add($item) }

    # An empty expected collection is vacuously present in any collection.
    if (0 -eq $expectedItems.Count) { return $true }

    # Copy the actual items so we can mark the ones we have already used.
    $actualItems = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $Actual) { $actualItems.Add($item) }

    # Marker object for actual items that were already matched. Using a fresh reference means
    # the user can put anything in the collection, including $null, and never collide with the
    # marker, because they can never get a reference to it.
    $consumed = [Object]::new()

    foreach ($expectedItem in $expectedItems) {
        $found = $false
        for ($a = 0; $a -lt $actualItems.Count; $a++) {
            # Skip items we have already consumed. Reference comparison, so $null actual items
            # are not treated as consumed.
            if ($consumed -eq $actualItems[$a]) { continue }
            # Compare with -eq, actual item on the left, to match the equality semantics of
            # PowerShell's -contains operator. Cast to [bool] so an actual item that is itself a
            # collection collapses to a single truthy/falsy result instead of a filtered array.
            if ([bool]($actualItems[$a] -eq $expectedItem)) {
                $actualItems[$a] = $consumed
                $found = $true
                break
            }
        }
        if (-not $found) { return $false }
    }

    return $true
}
