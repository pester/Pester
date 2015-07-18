
function PesterContain($file, $contentExpectation) {
    $re = [regex]::escape($contentExpectation)
    $ofs = "`n"
    if($file -is [string] -and !(Test-Path $file -ErrorAction SilentlyContinue)) {
        return "$file" -match $re
    } else {
        return "$(Get-Content $file)" -match $re
    }
}

function PesterContainFailureMessage($file, $contentExpectation) {
    return "Expected: file ${file} to contain {$contentExpectation}"
}

function NotPesterContainFailureMessage($file, $contentExpectation) {
    return "Expected: file {$file} to not contain ${contentExpectation} but it did"
}

