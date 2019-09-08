param($Thumbprint)
$ErrorActionPreference = 'Stop'

$cert = Get-ChildItem Cert:\CurrentUser\My |
Where-Object Thumbprint -eq $Thumbprint

if ($null -eq $cert) {
    throw "No certificate was found."
}

if (@($cert).Length -gt 1) {
    throw "More than one cerfificate with the given thumbprint was found."
}

"Signing Files"
$files = Get-ChildItem -Recurse -ErrorAction SilentlyContinue |
Where-Object { $_.Extension -in ".ps1", ".psm1", ".psd1", ".ps1xml", ".dll" } |
Select-Object -ExpandProperty FullName

$incorrectSignatures = Get-AuthenticodeSignature -FilePath $files | Where-Object { "Valid", "NotSigned" -notcontains $_.Status }
if ($incorrectSignatures) {
    throw "There are items in the repository that are signed but their signature is invalid, review:`n$($incorrectSignatures | Out-String)`n"
}

$filesToSign = $files | Where-Object { "NotSigned" -eq (Get-AuthenticodeSignature -FilePath $_ ).Status }

if (-not @($filesToSign)) {
    return "There are no files to sign, all the files in the repository are already signed."
}

$results = $filesToSign |
ForEach-Object {
    $r = Set-AuthenticodeSignature $_ -Certificate $cert -TimestampServer 'http://timestamp.digicert.com' -ErrorAction Stop
    $r | Out-String | Write-Host
    $r
}

$failed = $results | Where-Object { $_.Status -ne "Valid" }

if ($failed) {
    throw "Failed signing $($failed.Path -join "`n")"
}
