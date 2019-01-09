function Should-Exist($ActualValue, [switch] $Negate, [string] $Because) {
    <#
.SYNOPSIS
Does not perform any comparison, but checks if the object calling Exist is present in a PS Provider.
The object must have valid path syntax. It essentially must pass a Test-Path call.

.EXAMPLE
$actual = (Dir . )[0].FullName
PS C:\>Remove-Item $actual
PS C:\>$actual | Should -Exist

`Should -Exist` calls Test-Path. Test-Path expects a file,
returns $false because the file was removed, and fails the test.
#>
    [bool] $succeeded = & $SafeCommands['Test-Path'] $ActualValue

    if ($Negate) {
        $succeeded = -not $succeeded
    }

    $failureMessage = ''

    if (-not $succeeded) {
        if ($Negate) {
            $failureMessage = "Expected path $(Format-Nicely $ActualValue) to not exist,$(Format-Because $Because) but it did exist."
        }
        else {
            $failureMessage = "Expected path $(Format-Nicely $ActualValue) to exist,$(Format-Because $Because) but it did not exist."
        }
    }

    return & $SafeCommands['New-Object'] psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

Add-AssertionOperator -Name         Exist `
    -InternalName Should-Exist `
    -Test         ${function:Should-Exist}


function ShouldExistFailureMessage() {
}
function NotShouldExistFailureMessage() {
}
