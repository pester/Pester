
function PesterContainMultiline($file, $contentExpectation) {
    return ((Get-Content $file -delim [char]0) -match $contentExpectation)
}

function PesterContainMultilineFailureMessage($file, $contentExpectation) {
    return "Expected: file ${file} to contain {$contentExpectation}"
}

function NotPesterContainMultilineFailureMessage($file, $contentExpectation) {
    return "Expected: file {$file} to not contain ${contentExpectation} but it did"
}

