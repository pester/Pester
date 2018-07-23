function PesterBeTrue($ActualValue, [switch] $Negate, [string] $Because)
{
    if ($Negate) {
        return PesterBeFalse -ActualValue $ActualValue -Negate:$false -Because $Because
    }

    if (-not $ActualValue) {
        $failureMessage = "Expected `$true,$(Format-Because $Because) but got $(Format-Nicely $ActualValue)."
        return New-Object psobject -Property @{
            Succeeded      = $false
            FailureMessage = $failureMessage
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $true
    }
}

function PesterBeFalse($ActualValue, [switch] $Negate, $Because)
{
    if ($Negate) {
        return PesterBeTrue -ActualValue $ActualValue -Negate:$false -Because $Because
    }

    if ($ActualValue) {
        $failureMessage = "Expected `$false,$(Format-Because $Because) but got $(Format-Nicely $ActualValue)."
        return New-Object psobject -Property @{
            Succeeded      = $false
            FailureMessage = $failureMessage
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $true
    }
}


Add-AssertionOperator -Name BeTrue -Test $function:PesterBeTrue

Add-AssertionOperator -Name BeFalse -Test $function:PesterBeFalse



# to keep tests happy
function PesterBeTrueFailureMessage($ActualValue) { }
function NotPesterBeTrueFailureMessage($ActualValue) { }
function PesterBeFalseFailureMessage($ActualValue) { }
function NotPesterBeFalseFailureMessage($ActualValue) { }
