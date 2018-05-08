
function PesterBeOfType($ActualValue, $ExpectedType, [switch] $Negate, [string]$Because) {

    if($ExpectedType -is [string]) {
        # parses type that is provided as a string in brackets (such as [int])
        $parsedType = ($ExpectedType -replace '^\[(.*)\]$','$1') -as [Type]
        if ($null -eq $parsedType) {
            throw [ArgumentException]"Could not find type [$ParsedType]. Make sure that the assembly that contains that type is loaded."
        }

        $ExpectedType = $parsedType
    }

    $succeded = $ActualValue -is $ExpectedType
    if ($Negate) { $succeded = -not $succeded }

    $failureMessage = ''

    if ($null -ne $ActualValue) {
        $actualType = $ActualValue.GetType()
    } else {
        $actualType = $null
    }

    if (-not $succeded)
    {
        if ($Negate)
        {
            $failureMessage = "Expected the value to not have type $(Format-Nicely $ExpectedType) or any of its subtypes,$(Format-Because $Because) but got $(Format-Nicely $ActualValue) with type $(Format-Nicely $actualType)."
        }
        else
        {
            $failureMessage = "Expected the value to have type $(Format-Nicely $ExpectedType) or any of its subtypes,$(Format-Because $Because) but got $(Format-Nicely $ActualValue) with type $(Format-Nicely $actualType)."
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeded
        FailureMessage = $failureMessage
    }
}


Add-AssertionOperator -Name BeOfType `
                      -Test $function:PesterBeOfType `
                      -Alias 'HaveType'

function PesterBeOfTypeFailureMessage() {}

function NotPesterBeOfTypeFailureMessage() {}
