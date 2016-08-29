
function PesterContain($file, $contentExpectation) {
    return ((& $SafeCommands['Get-Content'] -Encoding UTF8 $file) -match $contentExpectation)
}

function PesterContainFailureMessage($file, $contentExpectation) {
    return "Expected: file ${file} to contain {$contentExpectation}"
}

function NotPesterContainFailureMessage($file, $contentExpectation) {
    return "Expected: file {$file} to not contain ${contentExpectation} but it did"
}

