function PesterBeNull($ActualValue, [switch] $Negate)
{
    if (-not $Negate) {
        if ($null -ne $ActualValue) {
            $failureMessage = "Expected `$null, but got {$ActualValue}."
            return New-Object psobject -Property @{
                Succeeded      = $false
                FailureMessage = $failureMessage
            }
        }
    
        return New-Object psobject -Property @{
            Succeeded      = $true
        }
    } else {
        if ($null -eq $ActualValue) {
            $failureMessage = "Expected the value to not be `$null, but got `$null."
            return New-Object psobject -Property @{
                Succeeded      = $false
                FailureMessage = $failureMessage
            }
        }
    
        return New-Object psobject -Property @{
            Succeeded      = $true
        }
    }
}


Add-AssertionOperator -Name BeNull -Test $function:PesterBeNull


# to keep tests happy
function PesterBeNullFailureMessage($ActualValue) { }
function NotPesterBeNullFailureMessage($ActualValue) { }