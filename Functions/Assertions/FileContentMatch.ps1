function PesterFileContentMatch($ActualValue, $ExpectedContent, [switch] $Negate) {
    $succeeded = (@(& $SafeCommands['Get-Content'] -Encoding UTF8 $ActualValue) -match $ExpectedContent).Count -gt 0

    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterFileContentMatchFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent
        }
        else
        {
            $failureMessage = PesterFileContentMatchFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent
        }
    }

    return & $SafeCommands['New-Object'] psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function PesterFileContentMatchFailureMessage($ActualValue, $ExpectedContent) {
    return "Expected: file {$ActualValue} to contain {$ExpectedContent}"
}

function NotPesterFileContentMatchFailureMessage($ActualValue, $ExpectedContent) {
    return "Expected: file {$ActualValue} to not contain {$ExpectedContent} but it did"
}

Add-AssertionOperator -Name FileContentMatch `
                      -Test $function:PesterFileContentMatch
