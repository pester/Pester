cd c:\temp
remove-item -Path C:\temp\tst -Recurse -Force
New-Item -ItemType Directory c:\temp\tst


$cb = 0
$content = "Describe 'Block$($cb++)' {
    $(foreach($t in 1..100){
        "It -Name 'test$t' {
            `$true
        }
        "
    })
}"


foreach ($f in 1..1) {
    Set-Content -encoding utf8 -path  "c:\temp\tst\file$f.tests.ps1" -value $content
}


"$PSScriptRoot\..\Pester.psd1", "Pester" | foreach {
    get-module pester | Remove-Module
    Import-Module $_
    $_

    $script:o = $null
    (Measure-Command {
            Invoke-Pester -Path c:\temp\tst
        }).TotalSeconds
}

