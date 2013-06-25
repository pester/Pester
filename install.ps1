# Intsall script adapted from 
# https://github.com/dahlbyk/posh-git/blob/master/install.ps1 
param([switch]$WhatIf = $false)
$modName = "Pester"

if($PSVersionTable.PSVersion.Major -lt 2) {
    Write-Warning "$modName requires PowerShell 2.0 or better; you have version $($Host.Version)."
    return
}

if(!(Test-Path $PROFILE)) {
    Write-Host "Creating PowerShell profile...`n$PROFILE"
    New-Item $PROFILE -Force -Type File -ErrorAction Stop -WhatIf:$WhatIf > $null
}


# Adapted from http://www.west-wind.com/Weblog/posts/197245.aspx
function Get-FileEncoding($Path) {
    $bytes = [byte[]](Get-Content $Path -Encoding byte -ReadCount 4 -TotalCount 4)

    if(!$bytes) { return 'utf8' }

    switch -regex ('{0:x2}{1:x2}{2:x2}{3:x2}' -f $bytes[0],$bytes[1],$bytes[2],$bytes[3]) {
        '^efbbbf'   { return 'utf8' }
        '^2b2f76'   { return 'utf7' }
        '^fffe'     { return 'unicode' }
        '^feff'     { return 'bigendianunicode' }
        '^0000feff' { return 'utf32' }
        default     { return 'ascii' }
    }
}

$installDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$profileLine = "import-module '$installDir\pester.psm1'"
if(Select-String -Path $PROFILE -Pattern $profileLine -Quiet -SimpleMatch) {
    Write-Host "It seems $modName is already installed..."
    return
}

Write-Host "Adding $modName to profile..."
@"

# Load $modName
$profileLine

"@ | Out-File $PROFILE -Append -WhatIf:$WhatIf -Encoding (Get-FileEncoding $PROFILE)

Write-Host "$modName sucessfully installed!" -ForegroundColor Green
Write-Host "Please reload your profile for the changes to take effect:"
Write-Host '    . $PROFILE'

