
function PesterMatch($value, $expectedMatch) {
    $ofs = "`n"
    if($value -isnot [string] -and $value -isnot [string[]] -and (Test-Path $value -ErrorAction SilentlyContinue)) {
        return "$(Get-Content $value)" -match $expectedMatch
    } else {
        return "$value" -match $expectedMatch
    }
}

function PesterMatchFailureMessage($value, $expectedMatch) {
    return "Expected: {$value} to match the expression {$expectedMatch}"
}

function NotPesterMatchFailureMessage($value, $expectedMatch) {
    return "Expected: ${value} to not match the expression ${expectedMatch}"
}

