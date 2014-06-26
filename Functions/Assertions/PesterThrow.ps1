
$ActualExceptionMessage = ""
$ActualExceptionWasThrown = $false

# because this is a script block, the user will have to
# wrap the code they want to assert on in { }
function PesterThrow([scriptblock] $script, $expectedErrorMessage) {
    $Script:ActualExceptionMessage = ""
    $Script:ActualExceptionWasThrown = $false

    try {
        # Redirect to $null so script output does not enter the pipeline
        & $script > $null
    } catch {
        $Script:ActualExceptionWasThrown = $true
        $Script:ActualExceptionMessage = $_.Exception.Message
        $Script:ActualExceptionLine = Get-ExceptionInfoSummary $_.InvocationInfo
    }

    if ($ActualExceptionWasThrown) {
        return Get-DoMessagesMatch $ActualExceptionMessage $expectedErrorMessage
    }
    return $false
}

function Get-DoMessagesMatch($value, $expected) {
    if ($expected -eq "") { return $false }
    return $value.Contains($expected)
}

function Get-ExceptionInfoSummary($info) {
    return "from {0}:{1} char {2}" -f $info.ScriptName,$info.ScriptLineNumber,$info.OffsetInLine

}

function PesterThrowFailureMessage($value, $expected) {
    if ($expected) {
      return "Expected: the expression to throw an exception with message {{{0}}}, an exception was {2}raised, message was {{{1}}} {3}" -f
              $expected, $ActualExceptionMessage,(@{$true="";$false="not "}[$ActualExceptionWasThrown]),$ActualExceptionLine
    } else {
      return "Expected: the expression to throw an exception"
    }
}

function NotPesterThrowFailureMessage($value, $expected) {
    if ($expected) {
        return "Expected: the expression not to throw an exception with message {{{0}}}, an exception was {2}raised, message was {{{1}}} {3}" -f
              $expected, $ActualExceptionMessage,(@{$true="";$false="not "}[$ActualExceptionWasThrown]),$ActualExceptionLine
    } else {
        return "Expected: the expression not to throw an exception. Message was {{{0}}} {1}" -f $ActualExceptionMessage,$ActualExceptionLine
    }
}
