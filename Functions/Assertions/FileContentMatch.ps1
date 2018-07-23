function PesterFileContentMatch($ActualValue, $ExpectedContent, [switch] $Negate, $Because) {
    $succeeded = (@(& $SafeCommands['Get-Content'] -Encoding UTF8 $ActualValue) -match $ExpectedContent).Count -gt 0

    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterFileContentMatchFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent -Because $Because
        }
        else
        {
            $failureMessage = PesterFileContentMatchFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent -Because $Because
        }
    }

    return & $SafeCommands['New-Object'] psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function PesterFileContentMatchFailureMessage($ActualValue, $ExpectedContent, $Because) {
    return "Expected $(Format-Nicely $ExpectedContent) to be found in file '$ActualValue',$(Format-Because $Because) but it was not found."
}

function NotPesterFileContentMatchFailureMessage($ActualValue, $ExpectedContent, $Because) {
    return "Expected $(Format-Nicely $ExpectedContent) to not be found in file '$ActualValue',$(Format-Because $Because) but it was found."
}

Add-AssertionOperator -Name FileContentMatch `
                      -Test $function:PesterFileContentMatch
