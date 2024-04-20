function Test-StringNullOrWhiteSpace ($Actual) {
    $Actual -is [string] -and -not ([string]::IsNullOrWhiteSpace($Actual))
}
