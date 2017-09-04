function PesterFileContentMatchMultiline($ActualValue, $ExpectedContent, [switch] $Negate) {
    $succeeded = [bool] ((Get-Content $ActualValue -delim ([char]0)) -match $ExpectedContent)

    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterFileContentMatchMultilineFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent
        }
        else
        {
            $failureMessage = PesterFileContentMatchMultilineFailureMessage -ActualValue $ActualValue -ExpectedContent $ExpectedContent
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function PesterFileContentMatchMultilineFailureMessage($ActualValue, $ExpectedContent) {
    return "Expected: file {$ActualValue} to contain {$ExpectedContent}"
}

function NotPesterFileContentMatchMultilineFailureMessage($ActualValue, $ExpectedContent) {
    return "Expected: file {$ActualValue} to not contain {$ExpectedContent} but it did"
}

Add-AssertionOperator -Name  FileContentMatchMultiline `
                      -Test  $function:PesterFileContentMatchMultiline
