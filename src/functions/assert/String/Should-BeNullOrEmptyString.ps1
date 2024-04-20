function Test-StringNullOrEmpty ($Actual) {
    $Actual -is [string] -and -not ([string]::IsNullOrEmpty($Actual))
}
