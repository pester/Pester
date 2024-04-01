function Get-AssertionMessage ($Expected, $Actual, $Option, [hashtable]$Data = @{}, $CustomMessage, $DefaultMessage, [switch]$Pretty)
{
    if (-not $CustomMessage)
    {
        $CustomMessage = $DefaultMessage
    }

    $expectedFormatted = Format-Nicely -Value $Expected -Pretty:$Pretty
    $actualFormatted = Format-Nicely -Value $Actual -Pretty:$Pretty

    $optionMessage = $null;
    if ($null -ne $Option -and $option.Length -gt 0)
    {
        if (-not $Pretty) {
            $optionMessage = "Used options: $($Option -join ", ")."
        }
        else {
            if ($Pretty) {
                $optionMessage = "Used options:$($Option | ForEach-Object { "`n$_" })."
            }
        }
    }


    $CustomMessage = $CustomMessage.Replace('<expected>', $expectedFormatted)
    $CustomMessage = $CustomMessage.Replace('<actual>', $actualFormatted)
    $CustomMessage = $CustomMessage.Replace('<expectedType>', (Get-ShortType -Value $Expected))
    $CustomMessage = $CustomMessage.Replace('<actualType>', (Get-ShortType -Value $Actual))
    $CustomMessage = $CustomMessage.Replace('<options>', $optionMessage)

    foreach ($pair in $Data.GetEnumerator())
    {
        $CustomMessage = $CustomMessage.Replace("<$($pair.Key)>", (Format-Nicely -Value $pair.Value))
    }

    if (-not $Pretty) {
        $CustomMessage
    }
    else
    {
        $CustomMessage + "`n`n"
    }
}