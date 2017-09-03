function PesterFileContentMatchExactly($ActualValue, $ExpectedContent, [switch] $Negate) {
    $succeeded = (@(& $SafeCommands['Get-Content'] -Encoding UTF8 $ActualValue) -cmatch $ExpectedContent).Count -gt 0

    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterFileContentMatchExactlyFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent
        }
        else
        {
            $failureMessage = PesterFileContentMatchExactlyFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent
        }
    }

    return & $SafeCommands['New-Object'] psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function PesterFileContentMatchExactlyFailureMessage($ActualValue, $ExpectedContent) {
    return "Expected: file {$ActualValue} to contain exactly {$ExpectedContent}"
}

function NotPesterFileContentMatchExactlyFailureMessage($ActualValue, $ExpectedContent) {
    return "Expected: file {$ActualValue} to not contain exactly {$ExpectedContent} but it did"
}

Add-AssertionOperator -Name FileContentMatchExactly `
                      -Test $function:PesterFileContentMatchExactly
