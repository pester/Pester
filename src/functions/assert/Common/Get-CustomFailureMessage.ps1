function Get-CustomFailureMessage ($CustomMessage, $Expected, $Actual)
{
    $formatted = $CustomMessage -f $Expected, $Actual
    $tokensReplaced = $formatted -replace '<expected>', $Expected -replace '<actual>', $Actual
    $tokensReplaced -replace '<e>', $Expected -replace '<a>', $Actual
}