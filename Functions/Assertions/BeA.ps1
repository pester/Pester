
function PesterBeA($value, $expectedType) {
    trap [System.Management.Automation.PSInvalidCastException] { return $false }
    if($expectedType -is [string] -and !($expectedType -as [Type])) {
        $expectedType = $expectedType -replace '^\[(.*)\]$','$1'
    }
    return [bool]($value -is $expectedType)
}

function PesterBeAFailureMessage($value, $expectedType) {
    if($expectedType -is [string] -and !($expectedType -as [Type])) {
        $expectedType = $expectedType -replace '^\[(.*)\]$','$1'
    }
    if($Type = $expectedType -as [type]) {
        return "Expected: ${value} to be a [$Type]"
    } else {
        return "Expected: ${value} to be a [$expectedType], but unable to find type [$expectedType]. Make sure that the assembly that contains that type is loaded."
    }
}

function NotPesterBeAFailureMessage($value, $expectedType) {
    if($expectedType -is [string] -and -not $expectedType -as [Type]) {
        $expectedType = $expectedType -replace '^\[(.*)\]$','$1'
    }
    if($Type = $expectedType -as [type]) {
        return "Expected: {$value} to be anything but a ${Type}, but it's a ${Type}"
    } else {
        return "Expected: ${value} to be anything but a [$expectedType], but unable to find type [$expectedType]. Make sure that the assembly that contains that type is loaded."
    }    
}

