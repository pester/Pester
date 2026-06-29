function Ensure-ExpectedIsNotCollection {
    param(
        $InputObject
    )

    if (Is-Collection $InputObject)
    {
        throw [ArgumentException]'You provided a collection to the -Expected parameter. Using a collection on the -Expected side is not allowed by this assertion, because it leads to unexpected behavior. To compare collections use Should-BeCollection, or a more specialized collection assertion such as Should-Any or Should-All.'
    }

    $InputObject
}
