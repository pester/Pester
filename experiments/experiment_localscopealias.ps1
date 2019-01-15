get-module -name a | remove-module
new-module -name a -scriptblock {
    $f = 10
} | import-module

& {
    function a { Write-Host hello }

    set-alias b a

    & $PSScriptRoot\file.ps1
}
