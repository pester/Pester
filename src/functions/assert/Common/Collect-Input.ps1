function Collect-Input ($ParameterInput, $PipelineInput, $IsInPipeline) {
    if ($IsInPipeline) {
        # We are called like this: 1 | Assert-Equal -Expected 1, we will get $local:Input in $PipelineInput and $true in $IsInPipeline (coming from $MyInvocation.ExpectingInput).

        if ($PipelineInput.Count -eq 0) {
            # When calling @() | Assert-Equal -Expected 1, the engine will special case it, and we will get empty array $local:Input, fix that
            # by returning empty array wrapped in array.
            , @()
        }
        else {
            # This is array of all the input, when we output it, the function will unwrap it. So we get the raw input on the output.
            $PipelineInput
        }
    }
    else {
        # This is exactly what was provided to the ActualParmeter, wrap it in array so the function return can unwrap it.
        , $ParameterInput
    }
}
