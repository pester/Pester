
function PesterContain($file, $contentExpecation) {
    return ((Get-Content $file) -match $contentExpecation)
}

function PesterContainFailureMessage($file, $contentExpecation) {
    return "Expected: file ${file} to contain {$contentExpecation}"
}

function NotPesterContainFailureMessage($file, $contentExpecation) {
    return "Expected: file {$file} to not contain ${contentExpecation} but it did"
}

Add-AssertionOperator -Name                      Contain `
                      -Test                      $function:PesterContain `
                      -GetPositiveFailureMessage $function:PesterContainFailureMessage `
                      -GetNegativeFailureMessage $function:NotPesterContainFailureMessage
