This function allows you to create custom Should assertions.

## Example

```powershell
function BeAwesome($ActualValue, [switch] $Negate)
{

    [bool] $succeeded = $ActualValue -eq 'Awesome'
    if ($Negate) { $succeeded = -not $succeeded }

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = "{$ActualValue} is not Awesome"
        }
        else
        {
            $failureMessage = "{$ActualValue} is not Awesome"
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

Add-AssertionOperator -Name  BeAwesome `
                    -Test  $function:BeAwesome `
                    -Alias 'BA'
```
```powershell
PS C:\> "bad" | should -BeAwesome
{bad} is not Awesome
```
