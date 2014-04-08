
$ActualExceptionMessage = ""
$ActualExceptionWasThrown = $false

# because this is a script block, the user will have to
# wrap the code they want to assert on in { }
function PesterThrow([scriptblock] $script, $expectedErrorMessage) {
    $Script:ActualExceptionMessage = ""
    $Script:ActualExceptionWasThrown = $false

    try {
        # Piping to Out-Null so results of script exeution
        # does not remain on the pipeline
        & $script | Out-Null
    } catch {
        $Script:ActualExceptionWasThrown = $true
        $Script:ActualExceptionMessage = $_.Exception.Message
    }

    if ($ActualExceptionWasThrown) {
        $match = (Get-DoMessagesMatch $ActualExceptionMessage $expectedErrorMessage)
        return $match
    }
    return $false
}

function Get-DoMessagesMatch($value, $expected) {
    if ($expected -eq "") { return $false }
    return $value.Contains($expected)
}

function PesterThrowFailureMessage($value, $expected) {
    if ($expected) {
      return "Expected: the expression to throw an exception with message {{{0}}}, an exception was {2}raised, message was {{{1}}}" -f
              $expected, $ActualExceptionMessage,(@{$true="";$false="not "}[$ActualExceptionWasThrown])
    } else {
      return "Expected: the expression to throw an exception"
    }
}

function NotPesterThrowFailureMessage($value, $expected) {
    if ($expected) {
        return "Expected: the expression not to throw an exception with message {{{0}}}, an exception was {2}raised, message was {{{1}}}" -f
              $expected, $ActualExceptionMessage,(@{$true="";$false="not "}[$ActualExceptionWasThrown])
    } else {
        return "Expected: the expression not to throw an exception. Message was {{{0}}}" -f $ActualExceptionMessage
    }
}

