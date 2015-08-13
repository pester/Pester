
function PesterContain($file, $contentExpecation) {
    return ((Get-Content -Encoding UTF8 $file) -match $contentExpecation)
}

function PesterContainFailureMessage($file, $contentExpecation) {
    return "Expected: file ${file} to contain {$contentExpecation}"
}

function NotPesterContainFailureMessage($file, $contentExpecation) {
    return "Expected: file {$file} to not contain ${contentExpecation} but it did"
}

