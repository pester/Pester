function Test-StringNotWhiteSpace ($Actual) {
    $Actual -is [string] -and -not ([string]::IsNullOrWhiteSpace($Actual))
}
