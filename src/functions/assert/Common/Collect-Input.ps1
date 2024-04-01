function Collect-Input ($ParameterInput, $PipelineInput)
{
    #source: http://www.powertheshell.com/input_psv3/
    $collectedInput = @($PipelineInput)

    $isInPipeline = $collectedInput.Count -gt 0
    if ($isInPipeline) {
        $collectedInput
    }
    else
    {
        $ParameterInput
    }
}