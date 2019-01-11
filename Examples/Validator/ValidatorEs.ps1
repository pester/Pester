function MiValidator($thing_to_validate) {
    return $thing_to_validate.StartsWith("s")
}

function Invoke-SomethingThatUsesMiValidator {
    param(
        [ValidateScript( {MiValidator $_})]
        $some_param
    )
}
