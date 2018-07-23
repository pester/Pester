function PesterContain($ActualValue, $ExpectedValue, [switch] $Negate, [string] $Because)
{
    [bool] $succeeded = $ActualValue -contains $ExpectedValue
    if ($Negate) { $succeeded = -not $succeeded }

    if (-not $succeeded)
    {
        if ($Negate)
        {
            return New-Object psobject -Property @{
                Succeeded      = $false
                FailureMessage = "Expected $(Format-Nicely $ExpectedValue) to not be found in collection $(Format-Nicely $ActualValue),$(Format-Because $Because) but it was found."
            }
        } else {
            return New-Object psobject -Property @{
                Succeeded      = $false
                FailureMessage = "Expected $(Format-Nicely $ExpectedValue) to be found in collection $(Format-Nicely $ActualValue),$(Format-Because $Because) but it was not found."
            }
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $true
    }
}

Add-AssertionOperator -Name Contain `
                      -Test $function:PesterContain `
                      -SupportsArrayInput

function PesterContainFailureMessage() { }
function NotPesterContainFailureMessage() {}

