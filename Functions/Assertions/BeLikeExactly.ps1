function PesterBeLikeExactly($ActualValue, $ExpectedValue, [switch] $Negate, [String] $Because)
{
    [bool] $succeeded = $ActualValue -clike $ExpectedValue
    if ($Negate) { $succeeded = -not $succeeded }

    if (-not $succeeded)
    {
        if ($Negate)
        {
            return New-Object psobject -Property @{
                Succeeded      = $false
                FailureMessage = "Expected case sensitive like wildcard $(Format-Nicely $ExpectedValue) to not match $(Format-Nicely $ActualValue),$(Format-Because $Because) but it did match."
            }
        }
        else
        {
            return New-Object psobject -Property @{
                Succeeded      = $false
                FailureMessage = "Expected case sensitive like wildcard $(Format-Nicely $ExpectedValue) to match $(Format-Nicely $ActualValue),$(Format-Because $Because) but it did not match."
            }
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $true
    }
}

Add-AssertionOperator -Name BeLikeExactly `
                      -Test  $function:PesterBeLikeExactly

function PesterBeLikeExactlyFailureMessage() { }
function NotPesterBeLikeExactlyFailureMessage() { }


