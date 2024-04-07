function Collect-Input ($ParameterInput, $PipelineInput, $IsPipelineInput) {
    if ($IsPipelineInput) {
        # We are called like this: 1 | Assert-Equal -Expected 1, we will get $local:Input in $PipelineInput and $true in $IsPipelineInput (coming from $MyInvocation.ExpectingInput).

        if ($PipelineInput.Count -eq 0) {
            # When calling @() | Assert-Equal -Expected 1, the engine will special case it, and we will get empty array in $local:Input
            $collectedInput = @()
        }
        else {
            # This is array of all the input, unwrap it.
            $collectedInput = foreach ($item in $PipelineInput) { $item }
        }
    }
    else {
        # This is exactly what was provided to the ActualParmeter.
        $collectedInput = $ParameterInput
    }

    @{
        Actual          = $collectedInput
        # We can use this to determine if collections are comparable. Pipeline input will unwind the collection, so pipeline input collection type is not comparable.
        IsPipelineInput = $IsPipelineInput
    }
}
