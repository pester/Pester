function PesterContainExactly($file, $contentExpectation) {
    return ((& $SafeCommands['Get-Content'] -Encoding UTF8 $file) -cmatch $contentExpectation)
}

function PesterContainExactlyFailureMessage($file, $contentExpectation) {
    return "Expected: file ${file} to contain exactly {$contentExpectation}"
}

function NotPesterContainExactlyFailureMessage($file, $contentExpectation) {
    return "Expected: file {$file} to not contain exactly ${contentExpectation} but it did"
}

