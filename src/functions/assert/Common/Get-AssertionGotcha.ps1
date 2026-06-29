function Get-AssertionGotcha {
    # Best-effort diagnostic hint shown when an assertion is *already failing* because the user
    # most likely piped the wrong shape into it (e.g. a single hashtable into a collection
    # assertion). It NEVER changes pass/fail and is only ever called from a failure branch, so it
    # has zero cost on the happy path. Returns a short hint string, or $null when there is nothing
    # useful to say or the underlying inspection is unavailable.
    #
    # This is the single home for input-shape "gotcha" wording. Add new cases here.
    param (
        # The calling assertion's $PSCmdlet. Used to recover the real left-hand side of the pipeline.
        [System.Management.Automation.PSCmdlet] $Cmdlet,
        # The calling assertion's $local:Input (object[] or $null).
        $Buffer,
        # The value the assertion actually compared ($collectedInput.Actual).
        $CollectedActual,
        # $collectedInput.IsPipelineInput.
        [bool] $IsPipelineInput,
        # What the failing assertion wanted the input to be. This selects the wording, because the
        # same wrong shape is a problem for different reasons depending on the assertion:
        #   Collection      - the whole input is compared as one collection (e.g. Should-BeCollection).
        #                     A lone scalar, $null, or dictionary is the wrong container, so all three
        #                     are worth a hint.
        #   CollectionItems - the input is iterated or searched item by item (e.g. Should-All,
        #                     Should-Any, Should-ContainCollection, Should-NotContainCollection). A
        #                     lone scalar or $null is a perfectly valid one-item collection here, so
        #                     only a dictionary -- which PowerShell silently passes through as a
        #                     single, non-iterated object -- is a genuine gotcha.
        #   ExactType       - the input is checked as a single value against a type (e.g.
        #                     Should-HaveType, Should-NotHaveType). Piping a collection unwraps it
        #                     (one item becomes a scalar, several become [object[]]), so the original
        #                     collection type is lost. Here a piped collection is the gotcha; a piped
        #                     scalar is fine.
        #   Scalar          - the input is inspected as a single value, but not for its type (e.g.
        #                     Should-Be, the string/boolean/comparison/null/hashtable assertions).
        #                     Piping a collection unwraps it the same way, so the assertion silently
        #                     inspects the collapsed value instead of the collection. Unlike
        #                     ExactType the wording is about the collection being flattened, not its
        #                     type changing, so even an [object[]] that stays an [object[]] is worth
        #                     pointing out.
        [ValidateSet('Collection', 'CollectionItems', 'ExactType', 'Scalar')]
        [string] $Expecting = 'Collection'
    )

    try {
        if ($Expecting -eq 'ExactType') {
            # Only piped input can be a gotcha here: a collection passed with -Actual keeps its real
            # type and asserts correctly. The PipelineSource trick recovers the *original* left-hand
            # side, so even though the assertion only ever sees the unwrapped remains we can tell:
            #   scalar     - a genuine single value was piped; it keeps its type, so nothing to say.
            #   collection - a real collection was piped and the pipeline unwrapped it (the gotcha).
            #   range/etc. - nothing we can name with confidence, so stay quiet.
            if (-not $IsPipelineInput) { return $null }
            $info = [Pester.PipelineSource]::Resolve($Cmdlet, @($Buffer))
            if ($info.Source -ne 'collection') { return $null }

            # An empty collection is sent through the pipeline as no items at all, so nothing was
            # unwrapped in the #2801 sense -- there is no surprising type change to explain.
            if ($info.Count -eq 0) { return $null }

            # The trick recovers the genuine piped type (e.g. [string[]]) and item count, neither of
            # which the failure message can show because the pipeline already unwrapped the value.
            # $CollectedActual is what the assertion actually compared, i.e. what the collection was
            # unwrapped into. The recovered count tells us which unwrapping happened:
            #   one item   -> the pipeline yields that single element, so a scalar reaches the assertion.
            #   many items -> the elements are streamed and re-collected into an [Object[]].
            $pipedType = Get-ShortType2 -Value $info.Value
            $seenType = Get-ShortType2 -Value $CollectedActual

            # If the pipeline did not change the observable type (e.g. an [Object[]] is streamed and
            # re-collected straight back into an [Object[]]), then the type was never lost and the
            # failure is a genuine mismatch. Saying "saw [Object[]], not the [Object[]] you piped"
            # would be nonsense, so there is nothing useful to hint.
            if ($seenType -eq $pipedType) { return $null }

            $advice = "To assert the type of a collection, pass it as the -Actual argument instead of piping it, e.g. -Actual `$value."

            if ($info.Count -eq 1) {
                return "You piped a $pipedType into a type assertion, but the pipeline unwraps a single-item collection to its one element, so the assertion saw a single $seenType, not the $pipedType you piped. $advice"
            }

            return "You piped a $pipedType into a type assertion, but the pipeline streams a multi-item collection and re-collects it as $seenType, so the assertion saw $seenType, not the $pipedType you piped. $advice"
        }

        if ($Expecting -eq 'Scalar') {
            # Same gotcha as ExactType -- a piped collection is unwrapped before the assertion sees
            # it -- but here the assertion does not care about the type, only the single value. So the
            # story is "your collection was collapsed into one value and inspected as a whole", which
            # is worth telling even when the collapsed value is still an [Object[]] (e.g. a piped
            # [Object[]] re-collected as [Object[]]). That is why this branch has no "type did not
            # change" guard, unlike ExactType.
            if (-not $IsPipelineInput) { return $null }
            $info = [Pester.PipelineSource]::Resolve($Cmdlet, @($Buffer))
            if ($info.Source -ne 'collection') { return $null }

            # An empty collection sends no items through the pipeline, so there is nothing that was
            # collapsed and nothing surprising to explain.
            if ($info.Count -eq 0) { return $null }

            $pipedType = Get-ShortType2 -Value $info.Value
            $seenType = Get-ShortType2 -Value $CollectedActual
            $advice = "To assert on a collection use Should-BeCollection or Should-BeEquivalent; to assert on a single value pass it as the -Actual argument instead of piping it, e.g. -Actual `$value."

            if ($info.Count -eq 1) {
                return "You piped a $pipedType into a single-value assertion, but the pipeline unwraps a single-item collection to its one element, so the assertion inspected that single $seenType instead of the collection. $advice"
            }

            return "You piped a $pipedType into a single-value assertion, but the pipeline streams a multi-item collection and re-collects it into a single $seenType, so the whole collection was inspected as one value. $advice"
        }
        if ($IsPipelineInput) {
            # Recover the original left-hand side, undoing the engine's single-item wrapping, so we
            # can tell "a single hashtable was piped" (scalar) from "a real 1-item collection".
            $info = [Pester.PipelineSource]::Resolve($Cmdlet, @($Buffer))
            # A genuine collection/range/stream is exactly what the assertion wants; stay quiet and
            # let the assertion's own size/content message do the talking. Only a non-collection
            # left-hand side (scalar) is worth a hint.
            if ($info.Source -ne 'scalar') { return $null }
            $value = $info.Value
            $piped = $true
        }
        else {
            # Parameter syntax (-Actual ...): we already hold the real value, nothing to recover.
            if (Is-Collection -Value $CollectedActual) { return $null }
            $value = $CollectedActual
            $piped = $false
        }

        # Classify the wrong shape once, then pick wording that fits the failing assertion.
        if ($null -eq $value) {
            $shape = 'null'
        }
        elseif ($value -is [System.Collections.IDictionary]) {
            $shape = 'dictionary'
        }
        else {
            $shape = 'scalar'
        }

        $detail = switch ($Expecting) {
            'Collection' {
                switch ($shape) {
                    'null' { 'It is treated as a single $null item, not an empty collection. Use @() to represent an empty collection.' }
                    'dictionary' { 'PowerShell treats a dictionary as a single object, not a collection. To assert on it as a hashtable use Should-BeHashtable, or compare its contents with Should-BeEquivalent.' }
                    'scalar' { 'It is treated as a single item. To assert on a one-item collection wrap it as ,$actual, or use Should-Be for a scalar value.' }
                }
            }
            'CollectionItems' {
                switch ($shape) {
                    # A lone scalar or $null is a valid one-item collection for an item-wise
                    # assertion, so there is nothing surprising to point out. Only a dictionary is.
                    'dictionary' { 'PowerShell treats a dictionary as a single object, so it is passed through as one item instead of being iterated. Enumerate it first, e.g. with $actual.GetEnumerator(), or its .Keys or .Values, or assert on it directly with Should-BeHashtable.' }
                    default { $null }
                }
            }
        }

        if (-not $detail) { return $null }

        $what = if ($shape -eq 'null') { '$null' } else { 'a single ' + (Get-ShortType2 -Value $value) }

        if ($piped) {
            "You piped $what into a collection assertion. $detail"
        }
        else {
            "-Actual is $what, which is not a collection. $detail"
        }
    }
    catch {
        # The hint is best-effort. If inspection fails (e.g. PowerShell internals change on a future
        # version) say nothing, so the assertion behaves exactly as it would without the hint.
        $null
    }
}
