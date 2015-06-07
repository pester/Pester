function PesterThrow([scriptblock] $ActualValue, $ExpectedMessage, [switch] $Negate) {
    $script:ActualExceptionMessage = ""
    $script:ActualExceptionWasThrown = $false

    try {
        do {
            $null = & $ActualValue
        } until ($true)
    } catch {
        $script:ActualExceptionWasThrown = $true
        $script:ActualExceptionMessage = $_.Exception.Message
        $script:ActualExceptionLine = Get-ExceptionLineInfo $_.InvocationInfo
    }

    [bool] $succeeded = $false

    if ($ActualExceptionWasThrown) {
        $succeeded = Get-DoMessagesMatch $script:ActualExceptionMessage $ExpectedMessage
    }

    if ($Negate) { $succeeded = -not $succeeded }

    $failureMessage = ''

    if (-not $succeeded)
    {
        if ($Negate)
        {
            $failureMessage = NotPesterThrowFailureMessage -ActualValue $ActualValue -ExpectedMessage $ExpectedMessage
        }
        else
        {
            $failureMessage = PesterThrowFailureMessage -ActualValue $ActualValue -ExpectedMessage $ExpectedMessage
        }
    }

    return New-Object psobject -Property @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function Get-DoMessagesMatch($ActualValue, $ExpectedMessage) {
    if ($ExpectedMessage -eq "") { return $false }
    return $ActualValue.Contains($ExpectedMessage)
}

function Get-ExceptionLineInfo($info) {
    # $info.PositionMessage has a leading blank line that we need to account for in PowerShell 2.0
    $positionMessage = $info.PositionMessage -split '\r?\n' -match '\S' -join "`r`n"
    return ($positionMessage -replace "^At ","from ")
}

function PesterThrowFailureMessage($ActualValue, $ExpectedMessage) {
    if ($ExpectedMessage) {
        return "Expected: the expression to throw an exception with message {{{0}}}, an exception was {2}raised, message was {{{1}}}`n    {3}" -f
               $ExpectedMessage, $ActualExceptionMessage,(@{$true="";$false="not "}[$ActualExceptionWasThrown]),($ActualExceptionLine  -replace "`n","`n    ")
    } else {
        return "Expected: the expression to throw an exception"
    }
}

function NotPesterThrowFailureMessage($ActualValue, $ExpectedMessage) {
    if ($ExpectedMessage) {
        return "Expected: the expression not to throw an exception with message {{{0}}}, an exception was {2}raised, message was {{{1}}}`n    {3}" -f
               $ExpectedMessage, $ActualExceptionMessage,(@{$true="";$false="not "}[$ActualExceptionWasThrown]),($ActualExceptionLine  -replace "`n","`n    ")
    } else {
        return "Expected: the expression not to throw an exception. Message was {{{0}}}`n    {1}" -f $ActualExceptionMessage,($ActualExceptionLine  -replace "`n","`n    ")
    }
}

Add-AssertionOperator -Name Throw `
                      -Test $function:PesterThrow
