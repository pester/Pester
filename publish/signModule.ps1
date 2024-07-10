param(
    [String] $TenantId,
    [String] $VaultUrl,
    [String] $CertificateName,
    [String] $Path
)
$ErrorActionPreference = 'Stop'

"Signing Files"
$files = Get-ChildItem -Recurse -ErrorAction SilentlyContinue $Path |
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

dotnet tool install --global AzureSignTool
if (0 -ne $LASTEXITCODE) { 
    throw "Failed to install AzureSignTool"
}
azuresigntool sign -kvu $VaultUrl -kvm -kvc $CertificateName -kvt $TenantId -du "https://pester.dev" -tr "http://timestamp.digicert.com" -v $filesToSign
if (0 -ne $LASTEXITCODE) { 
    throw "Failed to sign files"
}

$failed = $filesToSign | Get-AuthenticodeSignature | Where-Object { $_.Status -ne "Valid" }

if ($failed) {
    throw "Failed signing $($failed.Path -join "`n")"
}
