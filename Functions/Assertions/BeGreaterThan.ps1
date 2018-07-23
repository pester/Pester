function PesterBeGreaterThan($ActualValue, $ExpectedValue, [switch] $Negate, [string] $Because)
{
    if ($Negate) {
        return PesterBeLessOrEqual -ActualValue $ActualValue -ExpectedValue $ExpectedValue -Negate:$false -Because $Because
    }

    if ($ActualValue -le $ExpectedValue) {
        return New-Object psobject -Property @{
            Succeeded      = $false
            FailureMessage = "Expected the actual value to be greater than $(Format-Nicely $ExpectedValue),$(Format-Because $Because) but got $(Format-Nicely $ActualValue)."
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $true
    }
}


function PesterBeLessOrEqual($ActualValue, $ExpectedValue, [switch] $Negate, [string] $Because)
{
    if ($Negate) {
        return PesterBeGreaterThan -ActualValue $ActualValue -ExpectedValue $ExpectedValue -Negate:$false -Because $Because
    }

    if ($ActualValue -gt $ExpectedValue) {
        return New-Object psobject -Property @{
            Succeeded      = $false
            FailureMessage = "Expected the actual value to be less than or equal to $(Format-Nicely $ExpectedValue),$(Format-Because $Because) but got $(Format-Nicely $ActualValue)."
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $true
    }
}

Add-AssertionOperator -Name  BeGreaterThan `
                      -Test  $function:PesterBeGreaterThan `
                      -Alias 'GT'

Add-AssertionOperator -Name  BeLessOrEqual `
                      -Test  $function:PesterBeLessOrEqual `
                      -Alias 'LE'

#keeping tests happy
function PesterBeGreaterThanFailureMessage() {  }
function NotPesterBeGreaterThanFailureMessage() { }

function PesterBeLessOrEqualFailureMessage() {  }
function NotPesterBeLessOrEqualFailureMessage() { }



