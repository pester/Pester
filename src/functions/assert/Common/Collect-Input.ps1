function Collect-Input {
    param (
        # This is input when called without pipeline syntax e.g. Should-Be -Actual 1
        # In that case -ParameterInput $Actual will be 1
        $ParameterInput,
        # This is $local:input, which is the input that powershell collected from pipeline.
        # It is always $null or object[] containing all the received items.
        $PipelineInput,
        # This tell us if we were called by | syntax or not. Caller needs to pass in $MyInvocation.ExpectingInput.
        [Parameter(Mandatory)]
        [bool] $IsPipelineInput,
        # This unwraps input provided by |. The effect of this is that we get single item input directly,
        # and not wrapped in array. E.g. 1 | Should-Be  -> 1, and not 1 | Should-Be -> @(1).
        #
        # Single item assertions should always provide this parameter. Collection assertions should never
        # provide this parameter, because they should handle collections consistenly.
        #
        # This parameter does not apply to input provided by parameter sytax Should-Be -Actual 1
        [switch] $UnrollInput
    )

    if ($IsPipelineInput) {
        # We are called like this: 1 | Assert-Equal -Expected 1, we will get $local:Input in $PipelineInput and $true in $IsPipelineInput (coming from $MyInvocation.ExpectingInput).

        if ($PipelineInput.Count -eq 0) {
            # When calling @() | Assert-Equal -Expected 1, the engine will special case it, and we will get empty array in $local:Input
            $collectedInput = @()
        }
        else {
            if ($UnrollInput) {
                # This is array of all the input, unwrap it.
                $collectedInput = foreach ($item in $PipelineInput) { $item }
            }
            else {
                # This is array of all the input.
                $collectedInput = $PipelineInput
            }
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
