function MeinValidator($thing_to_validate) {
    return $thing_to_validate.StartsWith("s")
}

function Invoke-SomethingThatUsesMeinValidator {
    param(
        [ValidateScript( {MeinValidator $_})]
        $some_param
    )
}
