function Ensure-ExpectedIsNotCollection {
    param(
        $InputObject,
        # Name of the assertion that is doing the check, so the message can say which assertion refused
        # the collection. The stack trace shows the line in the test file, not the assertion, so without
        # the name here there is nothing that tells the user which assertion complained.
        [string] $Assertion
    )

    if (Is-Collection $InputObject)
    {
        $by = if ([string]::IsNullOrWhiteSpace($Assertion)) { 'this assertion' } else { $Assertion }
        throw [ArgumentException]"You provided a collection to the -Expected parameter. Using a collection on the -Expected side is not allowed by $by, because it leads to unexpected behavior. To compare collections use Should-BeCollection, or a more specialized collection assertion such as Should-Any or Should-All."
    }

    $InputObject
}
