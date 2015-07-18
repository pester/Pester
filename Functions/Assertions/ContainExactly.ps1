
function PesterContainExactly($file, $contentExpectation) {
    $re = [regex]::escape($contentExpectation)
    $ofs = "`n"
    if($file -is [string] -and !(Test-Path $file -ErrorAction SilentlyContinue)) {
        return "$file" -cmatch $re
    } else {
        return "$(Get-Content $file)" -cmatch $re
    }
}

function PesterContainExactlyFailureMessage($file, $contentExpectation) {
    return "Expected: file ${file} to contain exactly {$contentExpectation}"
}

function NotPesterContainExactlyFailureMessage($file, $contentExpectation) {
    return "Expected: file {$file} to not contain exactly ${contentExpectation} but it did"
}

