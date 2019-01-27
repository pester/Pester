cd c:\temp
remove-item -Path C:\temp\tst -Recurse -Force
New-Item -ItemType Directory c:\temp\tst
cd c:\temp\tst

$cb = 0
$content = "New-Block -Name 'Block$($cb++)' {
    $(foreach($t in 1..9000){
        "New-Test -Name 'test$t' {

        }
        "
    })
}"


foreach ($f in 1..1) {
    Set-Content -encoding utf8 -path  "c:\temp\tst\file$f.tests.ps1" -value $content
}


get-module Pester | remove-module

Get-MOdule pester
import-module C:\Projects\pester_main\new-runtimepoc\Pester.Runtime.psm1
import-module C:\Projects\pester_main\new-runtimepoc\Pester.RSpec.psm1

$c = Find-RSpecTestFile "c:\temp\tst" | foreach { New-BlockContainerObject -File $_}

Measure-Command {
    Find-test -BlockContainer (New-BlockContainerObject -ScriptBlock ([scriptblock]::Create($content))) -SessionState $ExecutionContext.SessionState
}
