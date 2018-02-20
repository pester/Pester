function PesterBeLike($ActualValue, $ExpectedValue, [switch] $Negate, [String] $Because)
{
    [bool] $succeeded = $ActualValue -like $ExpectedValue
    if ($Negate) { $succeeded = -not $succeeded }

    if (-not $succeeded)
    {
        if ($Negate)
        {
            return New-Object psobject -Property @{
                Succeeded      = $false
                FailureMessage = "Expected like wildcard $(Format-Nicely $ExpectedValue) to not match $(Format-Nicely $ActualValue),$(Format-Because $Because) but it did match."
            }
        }
        else
        {
            return New-Object psobject -Property @{
                Succeeded      = $false
                FailureMessage = "Expected like wildcard $(Format-Nicely $ExpectedValue) to match $(Format-Nicely $ActualValue),$(Format-Because $Because) but it did not match."
            }
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $true
    }
}

Add-AssertionOperator -Name BeLike `
                      -Test  $function:PesterBeLike

function PesterBeLikeFailureMessage() { }
function NotPesterBeLikeFailureMessage() { }


