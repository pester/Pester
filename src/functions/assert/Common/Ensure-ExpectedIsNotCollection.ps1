function Ensure-ExpectedIsNotCollection {
    param(
        $InputObject
    )

    if (Is-Collection $InputObject)
    {
        throw [ArgumentException]'You provided a collection to the -Expected parameter. Using a collection on the -Expected side is not allowed by this assertion, because it leads to unexpected behavior. Please use Should-Any, Should-All or some other specialized collection assertion.'
    }

    $InputObject
}
