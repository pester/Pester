
function PesterBeOfType($ActualValue, $ExpectedType, [switch] $Negate) {
    $hash = @{ Succeeded = $true }

    trap [System.Management.Automation.PSInvalidCastException] { $hash['Succeeded'] = $false; continue }

    if($ExpectedType -is [string] -and !($ExpectedType -as [Type])) {
        $ExpectedType = $ExpectedType -replace '^\[(.*)\]$','$1'
    }

    $hash['Succeeded'] = $ActualValue -is $ExpectedType

    if ($Negate) { $hash['Succeeded'] = -not $hash['Succeeded'] }

    $failureMessage = ''

    if (-not $hash['Succeeded'])
    {
        if ($Negate)
        {
            $failureMessage = NotPesterBeOfTypeFailureMessage -ActualValue $ActualValue -ExpectedType $ExpectedType
        }
        else
        {
            $failureMessage = PesterBeOfTypeFailureMessage -ActualValue $ActualValue -ExpectedType $ExpectedType
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $hash['Succeeded']
        FailureMessage = $failureMessage
    }
}

function PesterBeOfTypeFailureMessage($ActualValue, $ExpectedType) {
    if($ExpectedType -is [string] -and !($ExpectedType -as [Type])) {
        $ExpectedType = $ExpectedType -replace '^\[(.*)\]$','$1'
    }

    if($Type = $ExpectedType -as [type]) {
        return "Expected: {$ActualValue} to be of type [$Type]"
    } else {
        return "Expected: {$ActualValue} to be of type [$ExpectedType], but unable to find type [$ExpectedType]. Make sure that the assembly that contains that type is loaded."
    }
}

function NotPesterBeOfTypeFailureMessage($ActualValue, $ExpectedType) {
    if($ExpectedType -is [string] -and -not $ExpectedType -as [Type]) {
        $ExpectedType = $ExpectedType -replace '^\[(.*)\]$','$1'
    }
    if($Type = $ExpectedType -as [type]) {
        return "Expected: {$ActualValue} to be of any type except [${Type}], but it's a [${Type}]"
    } else {
        return "Expected: {$ActualValue} to be of any type except [$ExpectedType], but unable to find type [$ExpectedType]. Make sure that the assembly that contains that type is loaded."
    }
}

Add-AssertionOperator -Name BeOfType `
                      -Test $function:PesterBeOfType
