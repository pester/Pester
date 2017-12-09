function Verify-Type {
    param (
        [Parameter(ValueFromPipeline=$true)]
        $Actual,
        [Parameter(Mandatory=$true,Position=0)]
        [Type]$Expected
    )

    if ($Actual -isnot $Expected) {
        $message = "Expected value to be of type $($Expected.FullName)`n"+
        "Expected: '$($Expected.FullName)'`n"+
        "Actual  : '$($Actual.GetType().FullName)'" 
        throw [Exception]$message
    }
    
    $Actual
}