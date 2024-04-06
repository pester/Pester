function Collect-Input ($ParameterInput, $PipelineInput, $IsInPipeline) {
    if ($IsInPipeline) {
        $PipelineInput
    }
    else {
        $ParameterInput
    }
}
