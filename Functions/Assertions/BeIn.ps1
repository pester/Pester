function PesterBeIn($ActualValue, $ExpectedValue, [switch] $Negate, [string] $Because)
{
    [bool] $succeeded = $ExpectedValue -contains $ActualValue
    if ($Negate) { $succeeded = -not $succeeded }

    if (-not $succeeded)
    {
        if ($Negate)
        {
            return New-Object psobject -Property @{
                Succeeded      = $false
                FailureMessage = "Expected collection [$($ExpectedValue -join ',')] to not contain {$ActualValue},$(Format-Because $Because) but it was found."
            }
        }
        else
        {
            return New-Object psobject -Property @{
                Succeeded      = $false
                FailureMessage = "Expected collection [$($ExpectedValue -join ',')] to contain {$ActualValue},$(Format-Because $Because) but it was not found."
            }
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $true
        FailureMessage = $failureMessage
    }
}

Add-AssertionOperator -Name BeIn `
                      -Test $function:PesterBeIn


function PesterBeInFailureMessage() { }
function NotPesterBeInFailureMessage() { }
