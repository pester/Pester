
# because this is a script block, the user will have to
# wrap the code they want to assert on in { }
function PesterThrow([scriptblock] $script, $expectedErrorMessage) {
    $itThrew = $false
	$pester.ActualExceptionMessage = $null
    try {
        # Piping to Out-Null so results of script exeution
        # does not remain on the pipeline
        & $script | Out-Null
    } catch {

        $pester.ActualExceptionMessage = $_.Exception.Message
        if (($expectedErrorMessage) -and $pester.ActualExceptionMessage -cnotlike $expectedErrorMessage) {
            $itThrew = $false
        } else {
            $itThrew = $true
        }
    }

    return $itThrew
}

function PesterThrowFailureMessage($value, $expected) {
    if ($expected) {
      return "Expected: the expression to throw an exception with message {0}, But message was {1}" -f $expected, $pester.ActualExceptionMessage
    } else {
      return "Expected: the expression to throw an exception"
    }
}

function NotPesterThrowFailureMessage($value, $expected) {
    if ($expected) {
        return "Expected: the expression to not throw an exception with message {0}, But message was {1}" -f $expected, $pester.ActualExceptionMessage
    } else {
        return "Expected: the expression to not throw an exception. Message was {0}" -f $pester.ActualExceptionMessage
    }
}

