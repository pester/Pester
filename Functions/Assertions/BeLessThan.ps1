function PesterBeLessThan($ActualValue, $ExpectedValue, [switch] $Negate, [string] $Because)
{
    if ($Negate) {
        return PesterBeGreaterOrEqual -ActualValue $ActualValue -ExpectedValue $ExpectedValue -Negate:$false -Because $Because
    }

    if ($ExpectedValue -le $ActualValue) {
        return New-Object psobject -Property @{
            Succeeded      = $false
            FailureMessage = "Expected {$ExpectedValue} to be less than the actual value,$(Format-Because $Because) but got {$ActualValue}."
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $true
    }
}


function PesterBeGreaterOrEqual($ActualValue, $ExpectedValue, [switch] $Negate, [string] $Because)
{
    if ($Negate) {
        return PesterBeLessThan -ActualValue $ActualValue -ExpectedValue $ExpectedValue -Negate:$false -Because $Because
    }

    if ($ExpectedValue -gt $ActualValue) {
        return New-Object psobject -Property @{
            Succeeded      = $false
            FailureMessage = "Expected {$ExpectedValue} to be greater or equal to the actual value,$(Format-Because $Because) but got {$ActualValue}."
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $true
    }
}

Add-AssertionOperator -Name  BeLessThan `
                      -Test  $function:PesterBeLessThan `
                      -Alias 'LT'

Add-AssertionOperator -Name  BeGreaterOrEqual `
                      -Test  $function:PesterBeGreaterOrEqual `
                      -Alias 'GE'

#keeping tests happy
function PesterBeLessThanFailureMessage() {  }
function NotPesterBeLessThanFailureMessage() { }

function PesterBeGreaterOrEqualFailureMessage() {  }
function NotPesterBeGreaterOrEqualFailureMessage() { }


