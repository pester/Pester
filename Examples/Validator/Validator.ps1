function MyValidator($thing_to_validate) {
    return $thing_to_validate.StartsWith("s")
}

function Invoke-SomethingThatUsesMyValidator {
    param(
        [ValidateScript( {MyValidator $_})]
        $some_param
    )
}
