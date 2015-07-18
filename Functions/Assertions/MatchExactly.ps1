
function PesterMatchExactly($value, $expectedMatch) {
    $ofs = "`n"
    if($value -isnot [string] -and (Test-Path $file -ErrorAction SilentlyContinue)) {
        return "$(Get-Content $value)" -cmatch $expectedMatch
    } else {
        return "$value" -cmatch $expectedMatch
    }
}

function PesterMatchExactlyFailureMessage($value, $expectedMatch) {
    return "Expected: {$value} to exactly match the expression {$expectedMatch}"
}

function NotPesterMatchExactlyFailureMessage($value, $expectedMatch) {
    return "Expected: ${value} to not match the expression ${expectedMatch} exactly"
}

