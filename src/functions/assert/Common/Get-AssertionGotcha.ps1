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
        # What the failing assertion wanted the input to be.
        [ValidateSet('Collection')]
        [string] $Expecting = 'Collection'
    )

    if ($Expecting -ne 'Collection') { return $null }

    try {
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

        if ($null -eq $value) {
            $what = '$null'
            $detail = 'It is treated as a single $null item, not an empty collection. Use @() to represent an empty collection.'
        }
        elseif ($value -is [System.Collections.IDictionary]) {
            $what = 'a single ' + (Get-ShortType2 -Value $value)
            $detail = 'PowerShell treats a dictionary as a single object, not a collection. To check the number of entries use $actual.Count, or compare contents with Should-BeEquivalent.'
        }
        else {
            $what = 'a single ' + (Get-ShortType2 -Value $value)
            $detail = 'It is treated as a single item. To assert on a one-item collection wrap it as ,$actual, or use Should-Be for a scalar value.'
        }

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
