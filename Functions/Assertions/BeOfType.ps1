
function PesterBeOfType($value, $expectedType) {
    trap [System.Management.Automation.PSInvalidCastException] { return $false }
    if($expectedType -is [string] -and !($expectedType -as [Type])) {
        $expectedType = $expectedType -replace '^\[(.*)\]$','$1'
    }
    return [bool]($value -is $expectedType)
}

function PesterBeOfTypeFailureMessage($value, $expectedType) {
    if($expectedType -is [string] -and !($expectedType -as [Type])) {
        $expectedType = $expectedType -replace '^\[(.*)\]$','$1'
    }
    if($Type = $expectedType -as [type]) {
        return "Expected: ${value} to be of type [$Type]"
    } else {
        return "Expected: ${value} to be of type [$expectedType], but unable to find type [$expectedType]. Make sure that the assembly that contains that type is loaded."
    }
}

function NotPesterBeOfTypeFailureMessage($value, $expectedType) {
    if($expectedType -is [string] -and -not $expectedType -as [Type]) {
        $expectedType = $expectedType -replace '^\[(.*)\]$','$1'
    }
    if($Type = $expectedType -as [type]) {
        return "Expected: {$value} to be of any type except [${Type}], but it's a [${Type}]"
    } else {
        return "Expected: ${value} to be of any type except [$expectedType], but unable to find type [$expectedType]. Make sure that the assembly that contains that type is loaded."
    }
}
