function Verify-AssertionFailed {
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ScriptBlock]$ScriptBlock
    )

    $assertionExceptionThrown = $false
    $err = $null
    try {
        $null = & $ScriptBlock
    }
    catch [Exception]
    {
        $assertionExceptionThrown = ($_.FullyQualifiedErrorId -eq 'PesterAssertionFailed')
        $err = $_
        $err
    }
    
    if (-not $assertionExceptionThrown) {
        $result = if ($null -eq $err) { "no error was thrown!" } 
                  else { "other error was thrown!`n$($err | Format-List -Force * | Out-String)" }
        throw [Exception]"An error with FQEID 'PesterAssertionFailed' was expected but $result"
    }
}
