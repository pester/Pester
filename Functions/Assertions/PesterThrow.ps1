
# because this is a script block, the user will have to
# wrap the code they want to assert on in { }
function PesterThrow([scriptblock] $script) {
    $itThrew = $false
    try {
        # Piping to Out-Null so results of script exeution
        # does not remain on the pipeline
        & $script | Out-Null
    } catch {
        $itThrew = $true
    }

    return $itThrew
}

function PesterThrowFailureMessage($expected, $value) {
    return "Expected: the expression to throw an exception"
}

function NotPesterThrowFailureMessage($expected, $value) {
    return "Expected: the expression to not throw an exception"
}

