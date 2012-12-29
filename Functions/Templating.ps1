function Get-ReplacementArgs($template, $data) {
   $replacements = ($data.keys | %{
            if($template -match "@@$_@@") {
                $value = $data.$_ -replace "``", "" -replace "`'", ""
                "-replace '@@$_@@', '$value'"
            }
        })
   return $replacements
}

function Get-Template($fileName) {
    $path = '.\templates'
    if($Global:ModulePath) {
        $path = $global:ModulePath + '\templates'
    }
    return Get-Content ("$path\$filename")
}

function Invoke-Template($templatName, $data) {
    $template = Get-Template $templatName
    $replacments = Get-ReplacementArgs $template $data
    return Invoke-Expression "`$template $replacments"
}
